class CompetitorProductsController < ApplicationController
    include AllProducts
    include S3CommonMethods
    include HierarchyValidations
    include ProductsCommons

    before_action :is_parent_or_linked_customer, only: [:delete_all, :export, :preview, :delete_preview]

    def model
        CompetitorProduct
    end

    def index_url
        customer_competitor_products_url
    end

    def index_find

        if params[:customer_id] and params[:online_store] and params[:country]
            @customer = find_customer(params[:customer_id])

            if @customer.nil?
                return customer_error
            end

            @online_stores = @customer.online_stores
            online_store = @online_stores.find{ |store| store[:name].downcase == params[:online_store].downcase and store[:country].downcase == params[:country].downcase }

            if online_store.nil?
                return online_store_error
            end

            params[:customer_id] = @customer.id
            params[:online_store_id] = online_store.id
            model.select_all(params)

        elsif params[:online_store] and params[:country]
            @online_stores = []
            online_store = OnlineStore.find_by_name_and_country(params[:online_store].downcase, params[:country].downcase)

            if online_store.nil?
                return online_store_error
            end

            @online_stores << online_store

            params[:online_store_id] = online_store.id
            model.select_all(params)
        else
            @customer = find_customer(params[:customer_id])

            if @customer.nil?
                return customer_error
            end

            if !request.path_parameters[:format].nil? || !params[:format].nil?
                params[:customer_id] = @customer.id
                model.select_all(params)
            end
        end
    end

    def index

        # records are only returned by json
        # otherwise the view will render what it needs
        @records = index_find || []

        respond_to do |format|
            format.html { render :index }
            format.json { render json: @records }
        end
    end

    def get_all

        params[:all] = true
        @records = index_find || []

        respond_to do |format|
            format.json { render json: @records }
        end
    end

    def validate_classification_hierarchy

        # Delete previous errors
        flash[:error] = nil
        return customer_error unless load_customer

        unless params[:file].present?
            flash[:error] = "No file selected for upload"
            render :index
            return
        end

        @records = index_find

        @response, @record = create_product_previewer(@customer, params[:file], params[:delete_from_db])

        result, message, rows = @record.validate_header

        unless result
            @response[:error] = "Error in csv file => #{message}"
            return render json: @response
        end

        status_valid, @response = save_request_for_validation(rows, "IMPORT", @customer)

        if status_valid
            status, response = generate_classification_validation_with_async_status(@customer.id, @response[:request_id])
            return unless status
            @status = 202
            @response[:uid] = response["uid"]
            @response[:action_method] = "IMPORT"
            render json: @response
        else
            @status = 200
            render json: @response, status: @status
        end
    end

    def validate_classification_hierarchy_status

        @response = { message: "" }
        @status = 200

        status, pim_response = get_pim_api_async_processing_status(params[:uid])
        return unless status

        logger.info "Classification Hierarchy status received from PIM: #{pim_response}"

        @customer = Customer.find(params[:customer_id])
        errors = []
        case pim_response["status_name"]
            when "COMPLETE"
                errors = get_classification_hierarchy_errors(params[:uid])
                pim_response["status_name"] = "FAILED" if errors.present?

            when "FAILED"
                errors << ['',pim_response["error_message"]] if pim_response["error_message"].present?
        end
        
        if pim_response["status_name"] == "FAILED" && errors.present?
            s3_error, s3_response, s3_url = S3CommonMethods.generate_s3_log_files(errors, errors.length, 'competitor_product' , @customer)
            @response[:s3_message] = s3_response if !s3_error
            @response[:s3_url] = s3_url
        end

        if pim_response["status_name"] == "COMPLETE" || "FAILED"
            remove_request_for_validation(params[:uid])
        end

        @response[:http_status] = @status
        @response[:result] = pim_response["status_name"]

        render json: @response, status: @status
    end

    def preview
        # Delete previous errors
        flash[:error] = nil
        return customer_error unless load_customer

        unless params[:file].present?
            flash[:error] = "No file selected for upload"
            render :index
            return
        end

        @records = index_find

        @response, @record = create_product_previewer(@customer, params[:file], params[:delete_from_db])

        valid, message = competitor_products_standard_validation(@record)

        if valid
            render(:preview)
        else
            flash[:error] = "Error in csv file => #{message}"
            render(:index)
        end
    end

    def delete_preview

        # Delete previous errors
        flash[:error] = nil
        return customer_error unless load_customer

        unless params[:file].present?
            flash[:error] = "No file selected for upload"
            render :index
            return
        end

        @records = index_find

        valid_column_names = ['retailer', 'country', 'rpc']

        @record= DeleteCompetitorProductPreviewer.new(@customer, params[:file], valid_column_names, true)

        valid, message, @rows = @record.preview
        @products_to_delete = @record.products_to_delete
        @products_not_found = @record.products_not_found

        if valid
            render(:delete_preview)
        else
            flash[:error] = "Error in csv file => #{message}"
            redirect_to(customer_competitor_products_url(params[:customer_id]))
        end
    end

    def delete
        return customer_error unless load_customer

        success, error = delete_or_update_records(params[:to_be_deleted])

        if success
            flash[:success] = Translate.text('delete_result_competitor', newCount: @delete_record.deleted_count)
        else
            flash[:error] = "Error in csv file => #{error}"
        end

        redirect_to(customer_competitor_products_url(params[:customer_id]))
    end

    def create
        return customer_error unless load_customer
        added_count = params[:to_be_added_count].to_i

        del_or_update_records = params[:to_be_deleted] || params[:to_be_updated]

        delete_success, error = delete_or_update_records(del_or_update_records)

        if delete_success
            @import_record = CompetitorProductImporter.new(@customer, params[:to_be_added], current_user.email)
            import_success, error = @import_record.import
        end

        if delete_success && import_success
            result, msg = pim_update_candidates(added_count)
            flash[:error] = Translate.text('pim_update_candidates_error', newCount: added_count) unless result

            if result && params[:delete_all].match('true')
                flash[:success] = Translate.text('import_result_with_update_and_delete', added: added_count, updated: params[:to_be_updated_count], deleted: params[:to_be_deleted_count])
            elsif result
                flash[:success] = Translate.text('import_result_competitor', newCount: added_count)
                flash[:success] = params[:to_be_updated_count].to_i > 0 ? Translate.text('import_result_product_with_update', newCount: added_count, updated: params[:to_be_updated_count]) : Translate.text('import_result_competitor', newCount: added_count)
            end
        else
            flash[:error] = "Error in csv file => #{error}"
        end

        redirect_to(customer_competitor_products_url(params[:customer_id]))
    end

    def delete_or_update_records(del_or_update_records)
        @delete_record = CompetitorProductDeleter.new(@customer, del_or_update_records, current_user.email)
        delete_success, error = @delete_record.delete
        [delete_success, error]
    end

    def load_customer
        @customer = find_customer(params[:customer_id]) if params[:customer_id]
    end

    def delete_all

        return customer_error unless load_customer
        res, msg = model.delete_all_for_customer(@customer.id, current_user.email)
        if res == true
            flash[:success] = "All Records destroyed."
        else
            flash[:error] = 'Error deleting records for this customer ' + msg
        end

        redirect_to(customer_competitor_products_url)

    end

    def datatable

        return customer_error unless load_customer

        @records,@count_total,@count_filtered=DatatableRender.fetch_paged_result(
            @customer,
            params,
            [
                'competitor_products.manufacturer',
                'online_stores.name',
                'competitor_products.country',
                'competitor_products.rpc',
                'competitor_products.trusted_product_desc',
                'competitor_products.gtin',
                'competitor_products.brand',
                'competitor_products.category',
                'competitor_products.msrp',
                'competitor_products.min_price',
                'competitor_products.max_price',
                'competitor_products.url',
                'competitor_products.dimension1',
                'competitor_products.dimension2',
                'competitor_products.dimension3',
                'competitor_products.dimension4',
                'competitor_products.dimension5',
                'competitor_products.dimension6',
                'competitor_products.dimension7',
                'competitor_products.dimension8',
                'competitor_products.active',
                'competitor_products.status',
                'competitor_products.lookup_code'
            ],
            'competitor_products',
            'INNER JOIN online_stores ON competitor_products.online_store_id=online_stores.id',
        )
        render :template => 'shared/datatable'
    end

    def export

        if params[:online_store_id] and !params[:online_store_id].empty?

            @customer = find_customer(params[:customer_id])

            return customer_error if @customer.nil?

            @records = model.where(customer_id: @customer.id, online_store_id: params[:online_store_id])

        elsif params[:online_store_id] and params[:online_store_id].empty?

            @customer = find_customer(params[:customer_id])

            return customer_error if @customer.nil?

            @records = model.where(customer_id: @customer.id)
        end

        respond_to do |format|
            format.csv {  response.headers['Content-Disposition'] = 'attachment; filename="' + @customer.name.gsub(" ", '_') + '_competitor_products' + DateTime.now.to_s + '.csv"'}

        end

    end

    private

    def is_parent_or_linked_customer
        load_customer
        if @customer.is_standard_catalog_parent || @customer.standard_catalog_parent.present?
            redirect_to index_url
            flash[:error] = t("restrict_competitor_product_message", action_name: action_name ,  user_type: (@customer.is_standard_catalog_parent ? "Standard Catalog Parent" : "Linked Customer"))
        end
    end


end
