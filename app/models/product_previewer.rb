require 'csv'
class ProductPreviewer
    include ActiveModel::Validations
    include ModelUtils
    include Portal
    include PreviewerUtils
    extend ActiveModel::Naming

    attr_reader :errors, :to_be_added, :delete_all, :online_stores_product_count, :online_stores_product_count_updated, :online_stores_product_count_unchanged,
                :online_stores_product_count_delete, :duplicate_competitor, :duplicate_product, :duplicate_region_product, :not_in_trusted_source,
                :changed_competitor_brand_category, :new_competitor_rows, :updated_competitor_rows, :unchanged_competitor_rows, :deleted_competitor_rows,
                :new_competitor_rows_count, :deleted_competitor_rows_count, :new_product_rows, :updated_product_rows, :unchanged_product_rows, :deleted_product_rows,
                :new_product_rows_count, :deleted_product_rows_count, :delisted_product_rows

    TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE = "tmp_competitor_products_csv_file"

    def initialize(customer, file, valid_column_names, to_be_deleted, is_competitor_product=false)

        @customer = customer
        @file=file
        @errors = ActiveModel::Errors.new(self)
        @to_be_added = {}
        @online_stores_product_count = {}
        @online_stores_product_count_updated = {}
        @online_stores_product_count_unchanged = {}
        @online_stores_product_count_delete = {}
        @valid_column_names = valid_column_names
        @duplicate_competitor = []
        @duplicate_product = []
        @duplicate_region_product = []
        @delete_all = to_be_deleted.to_bool
        @not_in_trusted_source = []
        @is_competitor_product = is_competitor_product
        @changed_competitor_brand_category = []
        @new_competitor_rows = []
        @updated_competitor_rows = []
        @unchanged_competitor_rows = []
        @deleted_competitor_rows = []
        @new_competitor_rows_count = 0
        @deleted_competitor_rows_count = 0
        @new_product_rows = []
        @updated_product_rows = []
        @unchanged_product_rows = []
        @deleted_product_rows = []
        @new_product_rows_count = 0
        @deleted_product_rows_count = 0
        @delisted_product_rows = []
    end

    def preview()
        existing_region_products_in_csv = []
        rows_from_csv = []

        result, message = valid_header_row?
        return [false, message] unless result

        result, msg, rows_from_csv = read_csv_and_normalize_as_rows
        return [result, msg, ''] unless result

        # check that there are no blank retailer, rpc and country values in csv
        valid, message = validate_mandatory_values(rows_from_csv)
        return [false, message] unless valid

        # check for duplicated rows in csv
        validate_duplicated_rows(rows_from_csv,@errors)
        return [false,@errors.full_messages.first] if @errors.any?

        if @is_competitor_product
            result, message = create_temp_table_from_competitor_products_csv(rows_from_csv)
            return [result, message] unless result

            rows_retailer_rpc_country_downcased_from_csv = all_retailer_rpc_country_downcased_from_csv(rows_from_csv)

            # duplicate competitor list
            @duplicate_competitor = get_duplicate_competitor_products(rows_retailer_rpc_country_downcased_from_csv)

            # duplicate product list will only be retrieved if "Delete All" checkbox is unchecked
            @duplicate_product = get_duplicate_products(rows_retailer_rpc_country_downcased_from_csv)

            if !(@delete_all && !@is_competitor_product) && (@duplicate_competitor.size > 0 || @duplicate_product.size > 0 || @duplicate_region_product.size > 0)
                rows_from_csv = remove_all_duplicates(rows_from_csv, @duplicate_competitor, @duplicate_product, @duplicate_region_product)
            end
        end

        if @delete_all && @is_competitor_product
            #Competitors upload ticking the deleting checkbox
            rows_from_csv = parse_competitor_rows(rows_from_csv)
            add_index_to_rows_from_csv!(rows_from_csv)
            @changed_competitor_brand_category = get_changed_brand_category_competitor_products(rows_from_csv)

            if rows_from_csv.size > 0
                result, msg, rows_from_csv = validate_competitor_csv_rows(rows_from_csv, false)
                return [result, msg, rows_from_csv]
            end
        elsif @delete_all && !@is_competitor_product
            #Products CL upload ticking the deleting checkbox
            status, @not_in_trusted_source = products_not_in_trusted_source(rows_from_csv)
            return [status, @not_in_trusted_source] unless status

            #Step 0 - Necessary for get_unchanged_products to work
            result, message = create_temp_table_from_products_csv rows_from_csv
            return [result, message] unless result
            @duplicate_region_product = get_products_used_by_other_customers
            @duplicate_competitor = get_duplicates_in_competitor_tables
            if ( @duplicate_competitor.size > 0)
                remove_all_duplicates_from_temporary_table(@duplicate_region_product+@duplicate_competitor)
            end
            rows_from_csv = parse_product_rows

            if rows_from_csv.size > 0
                result, msg, rows_from_csv = validate_product_csv_rows(rows_from_csv, false)
                return [result, msg, rows_from_csv]
            end
        elsif !@delete_all && @is_competitor_product
            #Competitors CL upload not ticking the deleting checkbox
            rows_from_csv = parse_competitor_rows(rows_from_csv)
            add_index_to_rows_from_csv!(rows_from_csv)
            @changed_competitor_brand_category = get_changed_brand_category_competitor_products(rows_from_csv)

            if rows_from_csv.size > 0
                result, msg, rows_from_csv = validate_competitor_csv_rows(rows_from_csv, false)
                return [result, msg, rows_from_csv]
            end
        else
            #Products CL upload not ticking the deleting checkbox
            status, @not_in_trusted_source = products_not_in_trusted_source(rows_from_csv)
            return [status, @not_in_trusted_source] unless status

            #Step 0 - Necessary for get_unchanged_products to work
            result, message = create_temp_table_from_products_csv rows_from_csv
            return [result, message] unless result
            @duplicate_region_product = get_products_used_by_other_customers

            @duplicate_competitor = get_duplicates_in_competitor_tables
            if ( @duplicate_competitor.size > 0)
                remove_all_duplicates_from_temporary_table(@duplicate_region_product+@duplicate_competitor)
            end

            rows_from_csv = parse_product_rows(@delete_all)
            @duplicate_product = @unchanged_product_rows.map { |product| [product['retailer'], product['rpc'], product['country']] }

            if rows_from_csv.size > 0
                result, msg, rows_from_csv = validate_product_csv_rows(rows_from_csv, false)
                return [result, msg, rows_from_csv]
            end
        end

        [true, '', rows_from_csv]
    end

    def validate_header
        result, message = valid_header_row?
        return [false, message] unless result
        result, msg, rows_from_csv = read_csv_and_normalize_as_rows
        return [result, msg, ''] unless result
        return [true, message,rows_from_csv]
    end

    private

    def remove_all_duplicates(rows_from_csv, duplicate_competitor, duplicate_product, duplicate_region_product)
        existing_region_products_in_csv = duplicate_region_product.map { |dp| [dp[0].downcase, dp[1].downcase, dp[2].downcase] }
        all_records = Set.new(duplicate_competitor + duplicate_product + existing_region_products_in_csv)
        rows_from_csv.reject! {|row| row if all_records.include?([row['retailer'].downcase, row['rpc'].downcase, row['country'].downcase]) }
        rows_from_csv
    end

    def validate_product_csv_rows(rows_from_csv, get_counts = true)

        valid_brand_owner = @customer.short_customer_name.downcase
        valid_country = @customer.name.last(2).downcase

        # Already validated that retailer, rpc and country are not blank
        common_mandatory_keys = %w(active retailer)
        mandatory_keys = common_mandatory_keys + %w(brandowner country)

        rows_from_csv.each do |row|
            # if index is not available set retailer, country and rpc as row identifier

            row['index'] = row['index'] || ": #{row['retailer']} #{row['country']}, #{row['rpc']}"
            mandatory_keys.each do |key|
                case key
                when 'active'
                    unless (row['active']  == '1' || row['active'] == '0')
                        return [false, "active column value is incorrect in row #{row['index']}. Valid values are 0 and 1", nil]
                    end
                when 'retailer'
                    found_retailer = @customer.online_stores.map do |store|
                        store if store.name.downcase == row['retailer'].downcase && store.country.downcase == row['country'].downcase
                    end.compact
                    return [false, "Store not assigned to this customer .. row #{row['index']} please check retailer and country", nil] if
                        found_retailer.blank?
                    return [false, "Store Scrape Code is 'URL' but url field is blank in row #{row['index']}", nil] if
                        found_retailer.first.scrape_code == "URL" && row['url'].blank?
                    row['retailer'] = found_retailer.pop.name
                when 'brandowner'
                    if row['brandowner'].downcase != valid_brand_owner
                        return [false, "brandowner value is not valid in row #{row['index']}", nil]
                    end
                when 'country'
                    if row['country'].downcase != valid_country
                        return [false, "country value is not valid in row #{row['index']}", nil]
                    end
                end
            end

            if get_counts
                store_key = "#{row['retailer']},#{row['country']}"
                set_modified_counts(row, @online_stores_product_count, store_key)
            end
        end

        return [true, nil, rows_from_csv]
    end

    def validate_competitor_csv_rows(rows_from_csv, get_counts = true)

        @valid_brands = @customer.customer_brands.pluck(:name)
        @valid_categories = @customer.customer_categories.pluck(:name)
        @valid_dimension_values = @customer.dimensions.map { |dim| { dim.label => dim.dimension_values.pluck(:value).push("UNCATEGORIZED") } }.reduce({}, :merge)
        @valid_manufacturers = @customer.manufacturers.pluck(:name)

        # Already validated that retailer, rpc and country are not blank
        common_mandatory_keys = %w(active retailer)
        mandatory_keys = common_mandatory_keys + %w(brand category status dimensions manufacturer trusted_product_desc)

        mandatory_keys.each do |key|
            result, msg, rows_from_csv = are_column_values_valid?(rows_from_csv, key)
            return [result, msg, nil] unless result
        end

        if get_counts
            rows_from_csv.each do |row|
                store_key = "#{row['retailer']},#{row['country']}"
                set_modified_counts(row, @online_stores_product_count, store_key)
            end
        end

        return [true, nil, rows_from_csv]
    end

    def are_column_values_valid?(rows_from_csv, column_name)
        unless column_name == 'dimensions'
            column_values_with_index = get_column_values_with_index(rows_from_csv, column_name)
            column_values = get_column_values(rows_from_csv, column_name)
            unique_column_values = column_values.uniq.compact
        end

        case column_name
        when 'active'
            invalid_values = unique_column_values - ["1", "0"]
            if invalid_values.present? || blank_column_values?(column_values)
                invalid_value = column_values_with_index.detect{ |item| !item.has_value?("1") && !item.has_value?("0") }
                return [false, "active column value is incorrect in row #{invalid_value.keys.first}. Valid values are 0 and 1", nil]
            end
        when 'brand'
            if blank_column_values?(column_values)
                blank_value = get_blank_value_with_index(column_values_with_index)
                return [false, "brand value is blank in row #{blank_value.keys.first}", nil] if blank_value.present?
            end
            invalid_values = unique_column_values - @valid_brands
            if invalid_values.present?
                invalid_values.each do |value|
                    invalid_brand = column_values_with_index.detect{ |item| item.has_value?(value) }
                    found_brand_name = @valid_brands.detect{ |brand| brand.downcase == invalid_brand.values[0].downcase }
                    if invalid_brand && found_brand_name.blank?
                        return [false, "brand value '#{invalid_brand.values[0]}' is not valid in row #{invalid_brand.keys.first}", nil]
                    else
                        # replace the brand in csv with the correct case
                        replace_value_in_csv_row(rows_from_csv, 'brand', invalid_brand, found_brand_name)
                    end
                end
            end
        when 'category'
            if blank_column_values?(column_values)
                blank_value = get_blank_value_with_index(column_values_with_index)
                return [false, "category value is blank in row #{blank_value.keys.first}", nil]
            end
            invalid_values = unique_column_values - @valid_categories
            if invalid_values.present?
                invalid_values.each do |value|
                    invalid_category = column_values_with_index.detect{ |item| item.has_value?(value) }
                    found_category_name = @valid_categories.detect{ |category| category.downcase == invalid_category.values[0].downcase }
                    if invalid_category && found_category_name.blank?
                        return [false, "category value '#{invalid_category.values[0]}' is not valid in row #{invalid_category.keys.first}", nil]
                    else
                        # replace the category in csv with the correct case
                        replace_value_in_csv_row(rows_from_csv, 'category', invalid_category, found_category_name)
                    end
                end
            end
        when 'status'
            invalid_values = unique_column_values - ["1", "2"]
            if invalid_values.present? || blank_column_values?(column_values)
                invalid_value = column_values_with_index.detect{ |item| !item.has_value?("1") && !item.has_value?("2") }
                return [false, "status column value is incorrect in row #{invalid_value.keys.first}. Valid values are 1 or 2", nil]
            end
        when 'retailer'
            rows_from_csv.each do |row|
                found_retailer = @customer.online_stores.map do |store|
                    store if store.name.downcase == row['retailer'].downcase && store.country.downcase == row['country'].downcase
                end.compact
                return [false, "Store not assigned to this customer .. row #{row['index']} please check retailer and country", nil] if
                    found_retailer.blank?
                return [false, "Store Scrape Code is 'URL' but url field is blank in row #{row['index']}", nil] if
                    found_retailer.first.scrape_code == "URL" && row['url'].blank?
                row['retailer'] = found_retailer.pop.name
            end
        when 'dimensions'
            @valid_dimension_values.keys.each do |dimension_label|
                column_values_with_index = get_column_values_with_index(rows_from_csv, "#{dimension_label}")
                column_values = get_column_values(rows_from_csv, "#{dimension_label}")
                invalid_values = (column_values - @valid_dimension_values["#{dimension_label}"]).compact
                if invalid_values.present?
                    invalid_values.each do |value|
                        invalid_dimension = column_values_with_index.detect{ |item| item.has_value?(value) }
                        index_of_dimension = @valid_dimension_values[dimension_label].map(&:downcase).index(value.downcase)
                        if invalid_dimension && index_of_dimension
                            # replace the dimension value in csv with the correct case
                            valid_dimension_value = @valid_dimension_values[dimension_label][index_of_dimension]
                            replace_value_in_csv_row(rows_from_csv, "#{dimension_label}", invalid_dimension, valid_dimension_value)
                        else
                            error_message = invalid_dimension_error(dimension_label, value, "#{invalid_dimension.keys.first}")
                            if @valid_dimension_values[dimension_label].length >= 10
                               return [false, error_message = "#{error_message} + #{@valid_dimension_values[dimension_label].length-10} others", nil]
                            else
                               return [false, error_message, nil]
                            end
                        end
                    end
                end
            end
        when 'manufacturer'
            if blank_column_values?(column_values)
                blank_value = get_blank_value_with_index(column_values_with_index)
                return [false, "manufacturer value cannot be blank .. row #{blank_value.keys.first}", nil] if blank_value.present?
            end
            invalid_values = unique_column_values - @valid_manufacturers
            if invalid_values.present?
                invalid_values.each do |value|
                    invalid_manufacturer = column_values_with_index.detect{ |item| item.has_value?(value) }
                    found_manufacturer_name = @valid_manufacturers.detect{ |manufacturer| manufacturer.downcase == invalid_manufacturer.values[0].downcase }
                    if invalid_manufacturer && found_manufacturer_name.blank?
                        return [false, "manufacturer value is not valid in row #{invalid_manufacturer.keys.first}", nil]
                    else
                        # replace the manufacturer in csv with the correct case
                        replace_value_in_csv_row(rows_from_csv, 'manufacturer', invalid_manufacturer, found_manufacturer_name)
                    end
                end
            end
        when 'trusted_product_desc'
            if blank_column_values?(column_values)
                blank_value = get_blank_value_with_index(column_values_with_index)
                return [false, "trusted_product_desc value cannot be blank .. row #{blank_value.keys.first}", nil]
            end            
        end

        [true, nil, rows_from_csv]     
    end

    def get_column_values(rows_from_csv, column_name)
        rows_from_csv.map{ |row| row[column_name] }
    end

    def get_column_values_with_index(rows_from_csv, column_name)
        rows_from_csv.map{ |row| { row["index"] => row[column_name] } }
    end

    def blank_column_values?(column_values)
        column_values.any?(&:blank?)
    end

    def get_blank_value_with_index(column_values_with_index)
        column_values_with_index.detect{ |item| item.has_value?(nil) }
    end

    def set_online_store_counts(rows, count_attribute)
        if rows.size  > 0
            rows.each do |row|
                store_key=row['retailer']+','+row['country']
                set_modified_counts(row, count_attribute, store_key)
            end
        end
    end

    def set_modified_counts row, attribute, store_key
        if  !attribute[store_key]
            attribute[store_key]={retailer:row['retailer'],country:row['country'],count:1}
        else
            attribute[store_key][:count] += 1
        end
    end

    def create_data_structure_for_product_information(records)

        data = records.map { |record| [record['retailer'], record['rpc']] }
    end

    def retrieve_competitor_keys
        result = []
        result = ActiveRecord::Base.connection.execute(query('competitor_products')).to_a
        Set.new(result)
    end

    def retrieve_competitor_products_with_classifications
        query = <<-SQL.squish
            select lower(online_stores.name), lower(rpc), lower(online_stores.country), brand, category
            from competitor_products, online_stores
            where online_stores.id = online_store_id
            and customer_id = #{@customer.id}
        SQL
        ActiveRecord::Base.connection.execute(query).to_a
    end

    def retrieve_product_keys
        result = []
        unless @delete_all && !@is_competitor_product
            result = ActiveRecord::Base.connection.execute(query('products')).to_a.map{|e| e.map(&:downcase)}
        end
        Set.new(result)
    end

    def get_unchanged_products
        query_3 = "
            SELECT os.name, p.country, p.rpc, CONVERT(p.active,char), p.url
            from products p
            join products_csv_file pcf
            on p.customer_id = pcf.customer_id
              and p.online_store_id = pcf.online_store_id
              and p.rpc = pcf.rpc
              and p.country = pcf.country
              and p.active = pcf.active
              and COALESCE(p.url, '') = COALESCE(pcf.url, '')
            join online_stores os
              on pcf.online_store_id = os.id
            WHERE CONVERT(p.rpc, BINARY) = CONVERT(pcf.rpc, BINARY)
              and ((CONVERT(COALESCE(p.url, ''), BINARY) = CONVERT(COALESCE(pcf.url, ''), BINARY)))"
        result = ActiveRecord::Base.connection.execute(query_3)
        result.map { |r| @valid_column_names.first(3).zip(r).to_h }
    end

    def get_modified_products
        query_3 = "
            SELECT os.name, pcf.country, pcf.rpc, pcf.brand_owner, CONVERT(pcf.active,char), pcf.url
            from products p
            join products_csv_file pcf
            on p.customer_id = pcf.customer_id
              and p.online_store_id = pcf.online_store_id
              and p.rpc = pcf.rpc
              and p.country = pcf.country
            join online_stores os
              on pcf.online_store_id = os.id
            where COALESCE(p.active, false) != COALESCE(pcf.active, false)
              or COALESCE(p.url, '') != COALESCE(pcf.url, '')
              or CONVERT(p.rpc, BINARY) != CONVERT(pcf.rpc, BINARY)
              or (p.url IS NOT NULL and pcf.url IS NOT NULL and CONVERT(p.url, BINARY) != CONVERT(pcf.url, BINARY))"
        result = ActiveRecord::Base.connection.execute(query_3)
        result.map { |r| @valid_column_names.zip(r).to_h }
    end

    def get_added_products
        query_3 = "
            SELECT os.name, pcf.country, pcf.rpc, pcf.brand_owner, CONVERT(pcf.active,char), pcf.url
            from products p
            right join products_csv_file pcf
            on p.customer_id = pcf.customer_id
              and p.online_store_id = pcf.online_store_id
              and p.rpc = pcf.rpc
              and p.country = pcf.country
            join online_stores os
              on pcf.online_store_id = os.id
            where p.customer_id is null"
        result = ActiveRecord::Base.connection.execute(query_3)
        result.map { |r| @valid_column_names.zip(r).to_h }
    end

    def get_deleted_products
        query_3 = "
            SELECT os.name, p.country, p.rpc
            from products p
            left join products_csv_file pcf
            on p.customer_id = pcf.customer_id
              and p.online_store_id = pcf.online_store_id
              and p.rpc = pcf.rpc
              and p.country = pcf.country
            join online_stores os
              on p.online_store_id = os.id
            where p.customer_id = #{@customer.id} and pcf.customer_id is null"
        result = ActiveRecord::Base.connection.execute(query_3)
        .map { |r| @valid_column_names.first(3).zip(r).to_h }
    end

    def get_products_used_by_other_customers
        query_3 = "
            SELECT os.name, p.rpc, p.country, p.brand_owner
            from products p
            join products_csv_file pcf
            on p.online_store_id = pcf.online_store_id
              and p.rpc = pcf.rpc
              and p.country = pcf.country
            join online_stores os
              on pcf.online_store_id = os.id
            where p.customer_id != pcf.customer_id"
        result = ActiveRecord::Base.connection.execute(query_3).to_a
    end

    def get_duplicates_in_competitor_tables
        query= "
            SELECT os.name, cp.rpc, cp.country
            from competitor_products cp
            join products_csv_file pcf
            on cp.customer_id = pcf.customer_id
              and cp.online_store_id = pcf.online_store_id
              and cp.rpc = pcf.rpc
              and cp.country = pcf.country
            join online_stores os
              on pcf.online_store_id = os.id"
        result = ActiveRecord::Base.connection.execute(query).to_a
    end

    def create_temp_table_from_products_csv rows_from_csv
        query_0 = "drop temporary table if exists products_csv_file;"
        ActiveRecord::Base.connection.execute(query_0)

        query_1 = "CREATE TEMPORARY TABLE products_csv_file
            (
                `customer_id` int(11) DEFAULT NULL,
                `online_store_id` int(11) DEFAULT NULL,
                `rpc` varchar(60) DEFAULT NULL,
                `country` varchar(2) DEFAULT NULL,
                `active` tinyint(4) DEFAULT NULL,
                `url` text,
                `brand_owner` varchar(60) DEFAULT NULL
            )
        ".gsub(/\n/, '').squish
        ActiveRecord::Base.connection.execute(query_1)
        stores_map = @customer.online_stores.inject({}) do |stores_map,online_store|
            stores_map[online_store.name.downcase] = online_store.id
            stores_map
        end
        query_2_0 = 'INSERT INTO products_csv_file values '

        step = 1000
        (0..rows_from_csv.count-1).step(step).each do |start|
            query_2_1 = rows_from_csv[start...start+step].map do |row|
                store_id = stores_map[row['retailer'].downcase]
                return [false, "Online Store: #{row['retailer']} is not linked to this customer."] unless store_id
                return [false, "active column value is incorrect in row : #{row['retailer']} #{row['country']}, #{row['rpc']}. Valid values are 0 and 1"] unless ['1', '0'].include? row['active']
                "(#{@customer.id}, #{store_id}, #{ActiveRecord::Base.sanitize(row['rpc'])}, '#{row['country']}', #{row['active']}, #{ActiveRecord::Base.sanitize(row['url'])}, #{ActiveRecord::Base.sanitize(row['brandowner'])})"
            end

            ActiveRecord::Base.connection.execute(query_2_0 + query_2_1.join(','))
        end

        # Extracted into a method so it can be mocked in the tests
        create_index_in_temp_table
        [true, '']
    end

    def create_index_in_temp_table
        ActiveRecord::Base.connection.execute("CREATE index idx1 on products_csv_file(rpc,online_store_id, customer_id, country)")
    end

    def create_temp_table_from_competitor_products_csv rows_from_csv
        query_0 = "drop temporary table if exists #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE};"
        ActiveRecord::Base.connection.execute(query_0)

        query_1 = "CREATE TEMPORARY TABLE #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE}
            (
                `customer_id` int(11) DEFAULT NULL,
                `online_store_id` int(11) DEFAULT NULL,
                `country` varchar(2) DEFAULT NULL,
                `rpc` varchar(60) DEFAULT NULL,   
                `gtin` varchar(20) DEFAULT NULL,
                `trusted_product_desc` text,
                `brand` varchar(60) DEFAULT NULL,
                `category` varchar(255) DEFAULT NULL,
                `msrp` varchar(10) DEFAULT NULL,
                `min_price` varchar(10) DEFAULT NULL,
                `max_price` varchar(10) DEFAULT NULL,
                `url` text,
                `manufacturer` varchar(60) DEFAULT NULL,
                `dimension1` varchar(255) DEFAULT NULL,
                `dimension2` varchar(255) DEFAULT NULL,
                `dimension3` varchar(255) DEFAULT NULL,
                `dimension4` varchar(255) DEFAULT NULL,
                `dimension5` varchar(255) DEFAULT NULL,
                `dimension6` varchar(255) DEFAULT NULL,
                `dimension7` varchar(255) DEFAULT NULL,
                `dimension8` varchar(255) DEFAULT NULL,
                `active` tinyint(4) DEFAULT NULL,
                `status` tinyint(4) DEFAULT NULL,
                `lookup_code` varchar(60) DEFAULT NULL
            )
        ".gsub(/\n/, '').squish
        ActiveRecord::Base.connection.execute(query_1)
        create_index_in_competitors_temp_table
        stores_map = @customer.online_stores.inject({}) do |stores_map,online_store|
            stores_map[online_store.name.downcase] = online_store.id
            stores_map
        end
        query_2_0 = "INSERT INTO #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE} values "

        step = 2000
        (0..rows_from_csv.count-1).step(step).each do |start|
            query_2_1 = rows_from_csv[start...start+step].map do |row|
                store_id = stores_map[row['retailer'].downcase]
                return [false, "Online Store: #{row['retailer']} is not linked to this customer."] unless store_id
                return [false, "active column value is incorrect in row : #{row['retailer']} #{row['country']}, #{row['rpc']}. Valid values are 0 and 1"] unless ['1', '0'].include? row['active']
                "(#{@customer.id}, #{stores_map[row['retailer'].downcase]}, '#{row['country']}', #{ActiveRecord::Base.sanitize(row['rpc'])}, #{ActiveRecord::Base.sanitize(row['gtin'])}, #{ActiveRecord::Base.sanitize(row['trusted_product_desc'])}, #{ActiveRecord::Base.sanitize(row['brand'])}, #{ActiveRecord::Base.sanitize(row['category'])}, #{ActiveRecord::Base.sanitize(row['msrp'])}, #{ActiveRecord::Base.sanitize(row['min_price'])}, #{ActiveRecord::Base.sanitize(row['max_price'])}, #{ActiveRecord::Base.sanitize(row['url'])}, #{ActiveRecord::Base.sanitize(row['manufacturer'])}, #{ActiveRecord::Base.sanitize(row['dimension1'])}, #{ActiveRecord::Base.sanitize(row['dimension2'])}, #{ActiveRecord::Base.sanitize(row['dimension3'])}, #{ActiveRecord::Base.sanitize(row['dimension4'])}, #{ActiveRecord::Base.sanitize(row['dimension5'])}, #{ActiveRecord::Base.sanitize(row['dimension6'])}, #{ActiveRecord::Base.sanitize(row['dimension7'])}, #{ActiveRecord::Base.sanitize(row['dimension8'])}, #{row.key?('active') ? row['active'] : ActiveRecord::Base.sanitize(row['active'])},  #{row.key?('status') ? row['status'] : ActiveRecord::Base.sanitize(row['status'])},#{ActiveRecord::Base.sanitize(row['lookup_code'])})"
            end.join(',')

            ActiveRecord::Base.connection.execute(query_2_0 + query_2_1)
        end

        [true, '']
    end

    def create_index_in_competitors_temp_table
        ActiveRecord::Base.connection.execute("CREATE index idx2 on #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE}(rpc,online_store_id, customer_id, country)")
    end

    def get_added_competitor_products
        customer_dimension_columns = get_customer_dimension_column_names_in_temporary_table
        columns = "os.name, cpcf.country, cpcf.rpc, cpcf.gtin, cpcf.trusted_product_desc, cpcf.brand, cpcf.category, cpcf.msrp, cpcf.min_price, cpcf.max_price, cpcf.url, cpcf.manufacturer"
        columns += " ,#{customer_dimension_columns}" if @customer.dimensions.pluck(:label).size > 0
        columns += " ,CONVERT(cpcf.active,char), CONVERT(cpcf.status,char),cpcf.lookup_code"

        query_1 = "
            SELECT #{columns}
            FROM competitor_products cp
            RIGHT JOIN #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE} cpcf
            ON cp.customer_id = cpcf.customer_id
              AND cp.online_store_id = cpcf.online_store_id
              AND cp.rpc = cpcf.rpc
              AND cp.country = cpcf.country
            JOIN online_stores os
              ON cpcf.online_store_id = os.id
            WHERE cp.customer_id is null"

        result = ActiveRecord::Base.connection.execute(query_1.squish)
        result.map { |r| @valid_column_names.zip(r).to_h }
    end

    def get_unchanged_competitor_products
        customer_dimension_columns = get_customer_dimension_column_names_in_products_table
        columns = "os.name, cp.country, cp.rpc, cp.gtin, cp.trusted_product_desc, cp.brand, cp.category, cp.msrp, cp.min_price, cp.max_price, cp.url, cp.manufacturer"
        columns += " ,#{customer_dimension_columns}" if @customer.dimensions.pluck(:label).size > 0
        columns += " ,CONVERT(cpcf.active,char), CONVERT(cpcf.status,char),cpcf.lookup_code"

        query_1 = "
            SELECT #{columns}
            FROM competitor_products cp
            JOIN #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE} cpcf
            ON cp.customer_id = cpcf.customer_id
              AND cp.online_store_id = cpcf.online_store_id
              AND cp.rpc = cpcf.rpc
              AND cp.country = cpcf.country
              AND COALESCE(cp.gtin, '') = COALESCE(cpcf.gtin, '')
              AND COALESCE(cp.trusted_product_desc, '') = COALESCE(cpcf.trusted_product_desc, '')
              AND COALESCE(cp.brand, '') = COALESCE(cpcf.brand, '')
              AND COALESCE(cp.category, '') = COALESCE(cpcf.category, '')
              AND COALESCE(cp.msrp, 0) = COALESCE(cpcf.msrp, 0)
              AND COALESCE(cp.min_price, 0) = COALESCE(cpcf.min_price, 0)
              AND COALESCE(cp.max_price, 0) = COALESCE(cpcf.max_price, 0)
              AND COALESCE(cp.url, '') = COALESCE(cpcf.url, '')
              AND COALESCE(cp.manufacturer, '') = COALESCE(cpcf.manufacturer, '')\n"
        query_1 += unchanged_active_dimension_sql if @customer.dimensions.pluck(:label).size > 0
        query_1 += "\nAND COALESCE(cp.active, false) = COALESCE(cpcf.active, false)
              AND COALESCE(cp.status, 0) = COALESCE(cpcf.status, 0)
            JOIN online_stores os
            ON cpcf.online_store_id = os.id
            WHERE CONVERT(cp.rpc, BINARY) = CONVERT(cpcf.rpc, BINARY)
              AND ((CONVERT(COALESCE(cp.url, ''), BINARY) = CONVERT(COALESCE(cpcf.url, ''), BINARY)))"

        result = ActiveRecord::Base.connection.execute(query_1.squish)
        result.map { |r| @valid_column_names.first(3).zip(r).to_h }
    end

    def get_modified_competitor_products
        customer_dimension_columns = get_customer_dimension_column_names_in_temporary_table
        columns = "os.name, cpcf.country, cpcf.rpc, cpcf.gtin, cpcf.trusted_product_desc, cpcf.brand, cpcf.category, cpcf.msrp, cpcf.min_price, cpcf.max_price, cpcf.url, cpcf.manufacturer"
        columns += " ,#{customer_dimension_columns}" if @customer.dimensions.pluck(:label).size > 0
        columns += " ,CONVERT(cpcf.active,char), CONVERT(cpcf.status,char),cpcf.lookup_code"

        query_1 = "
            SELECT #{columns}
            FROM competitor_products cp
            JOIN #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE} cpcf
            ON cp.customer_id = cpcf.customer_id
              AND cp.online_store_id = cpcf.online_store_id
              AND cp.rpc = cpcf.rpc
              AND cp.country = cpcf.country
            JOIN online_stores os
              ON cpcf.online_store_id = os.id
            WHERE COALESCE(cp.gtin, '') != COALESCE(cpcf.gtin, '')
              OR COALESCE(cp.trusted_product_desc, '') != COALESCE(cpcf.trusted_product_desc, '')
              OR COALESCE(cp.brand, '') != COALESCE(cpcf.brand, '')
              OR COALESCE(cp.category, '') != COALESCE(cpcf.category, '')
              OR COALESCE(cp.msrp, 0) != COALESCE(cpcf.msrp, 0)
              OR COALESCE(cp.min_price, 0) != COALESCE(cpcf.min_price, 0)
              OR COALESCE(cp.max_price, 0) != COALESCE(cpcf.max_price, 0)
              OR COALESCE(cp.url, '') != COALESCE(cpcf.url, '')
              OR COALESCE(cp.manufacturer, '') != COALESCE(cpcf.manufacturer, '')\n"
        query_1 += modified_active_dimension_sql if @customer.dimensions.pluck(:label).size > 0
        query_1 += "\nOR COALESCE(cp.active, false) != COALESCE(cpcf.active, false)
              OR COALESCE(cp.status, 0) != COALESCE(cpcf.status, 0)
              OR CONVERT(cp.rpc, BINARY) != CONVERT(cpcf.rpc, BINARY)
              OR (cp.url IS NOT NULL and cpcf.url IS NOT NULL and CONVERT(cp.url, BINARY) != CONVERT(cpcf.url, BINARY))"

        result = ActiveRecord::Base.connection.execute(query_1.squish)
        result.map { |r| @valid_column_names.zip(r).to_h }
    end

    def get_deleted_competitor_products
        query_1 = "
            SELECT os.name, cp.country, cp.rpc
            FROM competitor_products cp
            LEFT JOIN #{TMP_TABLE_COMPETITOR_PRODUCTS_CSV_FILE} cpcf
            ON cp.customer_id = cpcf.customer_id
              AND cp.online_store_id = cpcf.online_store_id
              AND cp.rpc = cpcf.rpc
              AND cp.country = cpcf.country
            JOIN online_stores os
              ON cp.online_store_id = os.id
            WHERE cp.customer_id = #{@customer.id} and cpcf.customer_id is null"

        result = ActiveRecord::Base.connection.execute(query_1.squish)
        result.map { |r| @valid_column_names.first(3).zip(r).to_h }
    end

    def get_customer_dimension_column_names_in_temporary_table
        @customer.dimensions.pluck(:label).map { |label| "cpcf.#{label}"}.join(',')
    end

    def get_customer_dimension_column_names_in_products_table
        @customer.dimensions.pluck(:label).map { |label| "cp.#{label}"}.join(',')
    end

    def unchanged_active_dimension_sql
        @customer.dimensions.pluck(:label).map { |label| "and COALESCE(cp.#{label}, '') = COALESCE(cpcf.#{label}, '')\n"}.join
    end

    def modified_active_dimension_sql
        @customer.dimensions.pluck(:label).map { |label| "or COALESCE(cp.#{label}, '') != COALESCE(cpcf.#{label}, '')\n"}.join
    end

    def remove_all_duplicates_from_temporary_table(duplicates)
        # DELETE FROM table WHERE (col1,col2) IN ((1,2),(3,4),(5,6))
        query_3_0 = "DELETE FROM products_csv_file WHERE (online_store_id,rpc, country) IN "
        query_3_1 = duplicates.map do |duplicated_product|
            online_store_id = @customer.online_stores.find_by_name(duplicated_product).id
            "(#{online_store_id},'#{duplicated_product[1]}', '#{duplicated_product[2]}')"
        end.join(',')
        query_3 = query_3_0 + "("+query_3_1+")"
        result = ActiveRecord::Base.connection.execute(query_3)
    end

    def query_all(table, columns)
        "select online_stores.name, online_stores.country, rpc, #{columns.drop(3).join(',')} from #{table} , online_stores
        where online_stores.id = online_store_id
        and customer_id = #{@customer.id}".squish
    end

    def parse_competitor_rows(rows_from_csv)

        @new_competitor_rows = get_added_competitor_products
        @updated_competitor_rows = get_modified_competitor_products
        # update the @new_competitor_rows to include the new and updated rows
        @new_and_changed_competitor_rows = @new_competitor_rows + @updated_competitor_rows

        if @delete_all
            @deleted_competitor_rows = get_deleted_competitor_products
            @unchanged_competitor_rows = get_unchanged_competitor_products
        end

        set_online_store_and_competitor_counts

        # update the @deleted_competitor_rows to include the rows that have also been updated
        @deleted_competitor_rows += @updated_competitor_rows if @delete_all

        @new_competitor_rows = @new_and_changed_competitor_rows
        @new_and_changed_competitor_rows
    end

    def parse_product_rows delete_all = true
        # need to get just the new rows here to set new row count correctly
        @new_product_rows = get_added_products
        @unchanged_product_rows = get_unchanged_products
        @updated_product_rows = get_modified_products
        if delete_all
            @deleted_product_rows = get_deleted_products
        end
        @delisted_product_rows = @deleted_product_rows   # products to be delisted in trusted source (only those deleted)

        @new_and_changed_product_rows = @new_product_rows + @updated_product_rows

        set_online_store_and_product_counts

        # products to be deleted from control list (deleted and updated products)
        @deleted_product_rows += @updated_product_rows  if delete_all

        # products to be added to the control list - new and updated products
        @new_product_rows = @new_and_changed_product_rows

        @new_and_changed_product_rows
    end

    def get_changed_brand_category_competitor_products(rows_from_csv)
        existing_competitor_products = retrieve_competitor_products_with_classifications

        competitors_csv = rows_from_csv.map { |record|
            [record['retailer'].downcase, record['rpc'].downcase, record['country'].downcase, record['brand'], record['category']]
        }.compact

        changed_competitor_rows = existing_competitor_products - competitors_csv | competitors_csv - existing_competitor_products

        changed_competitor_rows = changed_competitor_rows.group_by { |row| [row[0], row[1], row[2]] }
        products = changed_competitor_rows.map {|key, values| values if values.size > 1 }.compact
    end

    def product_table_column_names(valid_column_names)
        valid_column_names.map { |column_name| column_name.gsub(/brandowner/, 'brand_owner') }
    end

    def customer_name_and_country()
        short_customer_name = @customer.short_customer_name
        country = @customer.name[short_customer_name.length...@customer.name.length].squish
        return [short_customer_name, country]
    end

    def get_duplicate_competitor_products(rows_retailer_rpc_country_downcased_from_csv)
        existing_competitors = retrieve_competitor_keys
        rows_retailer_rpc_country_downcased_from_csv.map { |record| record if existing_competitors.include? record}.compact
    end

    def get_duplicate_products(rows_retailer_rpc_country_downcased_from_csv)
        existing_products = retrieve_product_keys
        rows_retailer_rpc_country_downcased_from_csv.map { |record| record if existing_products.include? record}.compact
    end

    def products_not_in_trusted_source(rows_from_csv)
        short_customer_name, country = customer_name_and_country
        data = create_data_structure_for_product_information(rows_from_csv)
        res, not_in_trusted_source = validate_product_information(short_customer_name, country, data)
        unless res
            Rails.logger.error not_in_trusted_source
            return [false, 'Trusted source database error', '']
        end
          
        [true, not_in_trusted_source]  
    end

    def all_retailer_rpc_country_downcased_from_csv(rows_from_csv)
        rows_from_csv.map { |record| [record['retailer'].downcase, record['rpc'].downcase, record['country'].downcase] }.compact
    end

    def assign_online_store_product_counts
        set_online_store_counts(@new_product_rows, @online_stores_product_count)
        set_online_store_counts(@updated_product_rows, @online_stores_product_count_updated)
        set_online_store_counts(@unchanged_product_rows, @online_stores_product_count_unchanged)
        set_online_store_counts(@deleted_product_rows, @online_stores_product_count_delete)
    end

    def set_online_store_and_product_counts
        assign_online_store_product_counts
        @new_product_rows_count = @new_product_rows.size
        @deleted_product_rows_count = @deleted_product_rows.size
    end

    def assign_online_store_competitor_counts
        set_online_store_counts(@new_competitor_rows, @online_stores_product_count)
        set_online_store_counts(@updated_competitor_rows, @online_stores_product_count_updated)
        set_online_store_counts(@unchanged_competitor_rows, @online_stores_product_count_unchanged)
        set_online_store_counts(@deleted_competitor_rows, @online_stores_product_count_delete)
    end

    def set_online_store_and_competitor_counts
        assign_online_store_competitor_counts
        @new_competitor_rows_count = @new_competitor_rows.size
        @deleted_competitor_rows_count = @deleted_competitor_rows.size
    end

    def invalid_dimension_error(dimension_label, dimension_value, row_index)
        Translate.text('product_previewer_invalid_dimension',
                       dimension_label: dimension_label,
                       value: dimension_value,
                       row: row_index,
                       valid_dimension_values: @valid_dimension_values[dimension_label][0..10].join(', ')
                      )
    end

    def add_index_to_rows_from_csv!(rows_from_csv)
        rows_from_csv.each do |row|
            row['index'] = ": #{row['retailer']} #{row['country']}, #{row['rpc']}"
        end
    end

    def get_row_index(rows_in_csv, value_with_index)
        rows_in_csv.index { |row| row['index'] == value_with_index.keys.first }
    end

    def replace_value_in_csv_row(rows_from_csv, column_name, invalid_value, new_value)
        row_index = get_row_index(rows_from_csv, invalid_value)
        rows_from_csv[row_index][column_name] = new_value if row_index
    end
end
