require "spec_helper"

describe CompetitorProductsController do

    fixtures :customers, :users, :online_stores, :online_store_assignments, :competitor_products
    fixtures :settings
    login_user
    include ProductsCommons

    describe "GET #index" do

        it "renders the index template" do
            get :index, { :customer_id => 'Clavis' }
            expect(response).to render_template("index")
        end

        it "responds successfully with an HTTP 200 status code - JSON" do
            get :index, { :customer_id => 'Clavis', :format => :json }
            expect(response).to be_success
            expect(response.status).to eq(200)
        end

        it "responds successfully with an HTTP 200 status code" do
            get :index, { :customer_id => 'Clavis', :online_store => 'ClavisStore', :country => "AU" }
            expect(response).to be_success
            expect(response.status).to eq(200)
        end

        it "responds successfully with an HTTP 200 status code - JSON" do
            get :index, { :customer_id => 'Clavis', :online_store => 'ClavisStore', :country => "US", :format => :json }
            records = JSON.parse(response.body)
            competitor_details = []
            records.each do | record |
                competitor_details << record['gtin']
            end
            competitor_details.should include("12345678901234")
            expect(response).to be_success
            expect(response.status).to eq(200)
        end

        it "responds successfully with an HTTP 200 status code - JSON" do
            get :index, { :customer => 'Clavis', :online_store => 'invalid', :country => "AU", :format => :json }
            records = JSON.parse(response.body)
            records['error'].should eq("No Online Store Found")
        end

        it "responds successfully with an HTTP 200 status code - JSON" do
            get :index, { :customer_id => 'Invalid', :online_store => 'ClavisStore', :country => "AU", :format => :json }
            records = JSON.parse(response.body)
            records['error'].should eq("No Customer Found")
        end


        it "responds successfully with an HTTP 200 status code" do
            get :index, { :online_store => 'Test Store', :country => 'US'}
            expect(response).to be_success
            expect(response.status).to eq(200)
        end

        it "responds successfully with an HTTP 200 status code" do
            get :index, { :customer_id => "Clavis"}
            response.should render_template(:index)
            expect(response).to be_success
            expect(response.status).to eq(200)
        end

        it "responds with customer error message for invalid customer - JSON" do
            get :index, { :customer_id => 'Invalid', :format => :json }
            records = JSON.parse(response.body)
            expect(records["error"]).to eq("No Customer Found")

        end

        it "responds with 'No Online Store Found' for invalid store - JSON" do
            get :index, { :online_store => "Invalid", :country => "UK", :format => :json }
            records = JSON.parse(response.body)
            expect(records["error"]).to eq("No Online Store Found")

        end

        it "responds with 1 record with params customer_id - JSON" do
            get :index, { :customer_id => 'clavis', :format => :json }
            records = JSON.parse(response.body)
            products = []

            records.each do | record |
                products << record["rpc"]
            end

            expect(products).to include("B00004TBCD")
        end

        it "responds with 1 record with params [online_store, country] - JSON" do
            get :index, { :online_store => "ClavisStore UK", :country => "UK", :format => :json }
            records = JSON.parse(response.body)

            products = []
            records.each do | record |
                products << record["rpc"]
            end

            expect(products).to include("B00004TEFG")
            expect(products).to_not include("B00004TBCD")

        end

        it "responds with 1 record with params [online_store, country] - JSON" do
            get :index, { :online_store => "ClavisStore UK", :country => "UK", :format => :json }
            records = JSON.parse(response.body)

            products = []
            records.each do | record |
                products << record["rpc"]
            end

            expect(products).to include("B00004TEFG")
            expect(products).to_not include("B00004TBCD")

        end

        it "responds with 1 record with params [online_store, country]" do
            get :index, { :online_store => "Test Store", :country => "US", :format => :json }

            records = JSON.parse(response.body)
            products = []

            records.each do | record |
                products << record["rpc"]
            end

            expect(products).to include("B00004ABCD")
            expect(products).to_not include("B00004TBCD", "B00004TEFG")

        end

        it "responds with 1 record with params [online_store, country] status True" do
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1)
            competitor_product_2 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '124',
                                                    :status => 2)

            get :index, { :online_store => "First Store", :country => "US", :format => :json }

            records = JSON.parse(response.body)
            products = records.map { |record| record['rpc']}.flatten
            expect(products).to include('123')
            expect(products).to_not include('124')
            expect(response.status).to eq(200)

        end

        it "responds with 1 record with params [customer, online_store, country] status True" do
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            online_store_2 = FactoryGirl.create(:online_store, :name => 'Second Store', :country => 'US', :logo_content_type => nil)
            customer.online_stores << online_store << online_store_2
            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1)
            competitor_product_2 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '124',
                                                    :status => 2)
            competitor_product_3 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store_2.id,
                                                    :rpc => '125',
                                                    :status => 1)

            get :index, { :customer_id => customer.name, :online_store => "First Store", :country => "US", :format => :json }

            records = JSON.parse(response.body)
            products = records.map { |record| record['rpc']}.flatten
            expect(products).to include('123')
            expect(products).to_not include('124')
            expect(response.status).to eq(200)

        end

        it "responds with 1 record with params [customer] status True" do
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1)
            competitor_product_2 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '124',
                                                    :status => 2)

            get :index, { :customer_id => customer.name, :format => :json }

            records = JSON.parse(response.body)
            first_record = records[0]
            products = records.map { |record| record['rpc']}.flatten

            expect(products).to include('123')
            expect(products).to_not include('124')
            expect(response.status).to eq(200)
        end

        it "responds successfully with last_seen_date as null when a value is not defined - format json" do
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1)
            competitor_product_2 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '124',
                                                    :status => 2)

            get :index, { :customer_id => customer.name, :format => :json }

            records = JSON.parse(response.body)
            expect(response.status).to eq(200)
            expect(records.first['last_seen_date']).to be nil
        end

        it "responds successfully with last_seen_date when a value is defined - format json" do
            dateTimeNow = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1,
                                                    :last_seen_date => dateTimeNow)

            get :index, { :customer_id => customer.name, :format => :json }

            records = JSON.parse(response.body)
            expect(response.status).to eq(200)
            expect(DateTime.parse(records.first['last_seen_date']).strftime('%Y-%m-%d %H:%M:%S')).to eq(dateTimeNow)
        end
    end

    describe "GET #get_all" do

        it "responds with all customer records regardless of status if request params contain online store" do
            customer = FactoryGirl.create(:customer, :name => 'First Customer US')
            online_store = FactoryGirl.create(:online_store, :name => 'First Store', :country => 'US', :logo_content_type => nil)
            customer.online_stores << online_store

            competitor_product_1 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '123',
                                                    :status => 1)
            competitor_product_2 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '124',
                                                    :status => 2)
            competitor_product_3 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '125',
                                                    :status => 1)
            competitor_product_4 = FactoryGirl.create(:competitor_product,
                                                    :customer_id => customer.id,
                                                    :online_store_id => online_store.id,
                                                    :rpc => '126',
                                                    :status => 2)

            get :get_all, { :online_store => online_store.name, :country => 'US', :format => :json }

            records = JSON.parse(response.body)
            products = records.map { |record| record['rpc']}.flatten

            expect(products.size).to eq(4)
            expect(products).to include('123')
            expect(products).to include('124')
            expect(products).to include('125')
            expect(products).to include('126')

            expect(response.status).to eq(200)
        end

    end

    describe "Post #datatable" do
        render_views

        it "datatable responds with 1 records with page size 1 on page 1 - JSON" do
            post :datatable, {
                :customer_id => 'clavis',
                :format => :json,
                :draw => 2,
                :length => 1,
                :start =>0,
                :order => {'0'=>{:column => 1 , :dir=>'asc'}},
                :search => {'value'=>''},
            }
            records = JSON.parse(response.body)
            expect(records['draw']).to  eq(2)
            expect(records['recordsTotal']).to  eq(3)
            expect(records['recordsFiltered']).to  eq(3)
            expect(records['data'].length).to  eq(1)

            products = []
            records['data'].each do | record |
                products << record[3]
            end

            expect(products).to include("B00004TBCD")
        end

        it "datatable responds with 1 records with page size 1 on page 2 - JSON" do
            post :datatable, {
                :customer_id => 'clavis',
                :format => :json,
                :draw => 2,
                :length => 1,
                :start =>1,
                :order => {'0'=>{:column => 1 , :dir=>'asc'}},
                :search => {'value'=>''},
            }
            records = JSON.parse(response.body)
            expect(records['draw']).to  eq(2)
            expect(records['recordsTotal']).to  eq(3)
            expect(records['recordsFiltered']).to  eq(3)
            expect(records['data'].length).to  eq(1)

            products = []
            records['data'].each do | record |
                products << record[3]
            end

            expect(products).to include("B00004TEFG")
        end

        it "datatable responds with 1 records with search B00004TEFG - JSON" do
            post :datatable, {
                :customer_id => 'clavis',
                :format => :json,
                :draw => 2,
                :length => 3,
                :start =>0,
                :order => {'0'=>{:column => 3 , :dir=>'asc'}},
                :search => {'value'=>'B00004TEFG'},
            }
            records = JSON.parse(response.body)
            expect(records['draw']).to  eq(2)
            expect(records['recordsTotal']).to  eq(3)
            expect(records['recordsFiltered']).to  eq(1)
            expect(records['data'].length).to  eq(1)

            products = []
            records['data'].each do | record |
                products << record[3]
            end

            expect(products).to include("B00004TEFG")
        end

    end

    describe "Delete #delete_all" do
        it "deletes all competitor products records" do
            session[:username] = "test_user@clavis.com"
            lambda {delete :delete_all, :customer_id => "Clavis"}.should change(CompetitorProduct, :count).by(-3)
            response.should redirect_to (:index)
            flash[:success].should eq('All Records destroyed.')
        end

        it "validate delete all when the customer is parent" do
            parent_customer = FactoryGirl.create(:customer, :name => 'New_Parent_Customer_1', is_standard_catalog_parent: true)
            lambda {delete :delete_all, :customer_id => parent_customer.id}.should_not change(CompetitorProduct, :count)
            response.should redirect_to (:index)
            flash[:error].should eq("You can't delete_all products for Standard Catalog Parent")
        end

        it "validate delete all when the customer is linked" do
            parent_customer = FactoryGirl.create(:customer, :name => 'New_Parent_Customer_1', is_standard_catalog_parent: true)
            linked_customer = FactoryGirl.create(:customer, :name => 'Linked_Customer_1', standard_catalog_parent_id: parent_customer.id)
            lambda {delete :delete_all, :customer_id => linked_customer.id}.should_not change(Product, :count)
            response.should redirect_to (:index)
            flash[:error].should eq("You can't delete_all products for Linked Customer")
        end

    end

    describe "Get #export - Export csv" do
        render_views

        headers = nil
        values = nil

        before(:each) do
            headers = valid_column_names = ['retailer', 'country', 'rpc', 'gtin', 'trusted_product_desc', 'brand', 'category', 'msrp', 'min_price', 'max_price', 'url', 'manufacturer',
                                            'dimension1', 'dimension2', 'dimension3', 'dimension4', 'dimension5', 'dimension6', 'dimension7', 'dimension8', 'active', 'status', 'lookup_code']

            values = ['B00004TBCD', '12345678901234', 'Trusted Product Description', 'Known Brand', 'dimension1', 'dimension2', 'dimension3', 'dimension4', 'dimension5',
                    'dimension6', 'dimension7', 'dimension8', 'msrp', '10', '20', 'Test Url', 'Test Manufacturer', 'Known Category', 'AU', 'ClavisStore', '1', '1',nil]
        end

        it "responds successfully with csv file" do
            get :export, :customer_id => 'Clavis', :online_store_id => "1", :format => :csv

            csv = CSV.parse(response.body)

            csv.first.each do |field|
                expect(headers).to include(field.force_encoding("UTF-8").gsub("\xEF\xBB\xBF", ''))
            end

            csv.slice(1).each do |field|
                expect(values).to include(field)
            end

            expect(csv.slice(2)).to eq([])
        end

        it "responds successfully with csv file when online_store_id is empty " do
            get :export, :customer_id => 'Clavis', :online_store_id => "", :format => :csv

            values2 = ['ClavisStore UK', 'UK', 'B00004TEFG', '12345678901234', 'Trusted Product Description', 'Known Brand', 'Known Category', 'msrp', '10', '20', 'Test Url',
                     'Test Manufacturer', 'dimension1', 'dimension2', 'dimension3', 'dimension4', 'dimension5', 'dimension6', 'dimension7', 'dimension8', '1', '1',nil]

            values3 = ['Test Store', 'US', 'B00004ABCD', '12345678901234', 'Trusted Product Description', 'Known Brand', 'Known Category', 'msrp', '10', '20', 'Test Url',
                     'Test Manufacturer', 'dimension1', 'dimension2', 'dimension3', 'dimension4', 'dimension5', 'dimension6', 'dimension7', 'dimension8', '1', '1', nil]

            values_list = [values, values2, values3]

            csv = CSV.parse(response.body)

            csv.first.each do |field|
                expect(headers).to include(field.force_encoding("UTF-8").gsub("\xEF\xBB\xBF", ''))
            end

            values_list.each_with_index do |row, index|
                csv.slice(index+1).each do |field|
                    expect(row).to include(field)
                end
            end

            expect(csv.slice(4)).to eq([])
        end

        context 'It correctly returns lookup_code' do

          let!(:competitor_product) { FactoryGirl.create(:competitor_product,
                                                  :customer_id => 1,
                                                  :online_store_id => "5",
                                                  :rpc => '1234',
                                                  :status => 1,
                                                  :lookup_code => 'RPC423123-12234')}

            it "responds successfully with csv file with lookup_code header and corresponding value" do
                get :export, :customer_id => 'Clavis', :online_store_id => "5", :format => :csv
                csv = CSV.parse(response.body)
                csv.first.each do |field|
                    expect(headers).to include(field.force_encoding("UTF-8").gsub("\xEF\xBB\xBF", ''))
                end
                expect(csv[0]).to include("lookup_code")
                expect(csv[1]).to include("RPC423123-12234")
            end
        end

        it "validate export when the customer is standard parent" do
            parent_customer = FactoryGirl.create(:customer, name: 'First Customer US', is_standard_catalog_parent: true)
            online_store = FactoryGirl.create(:online_store, name: 'Amazon', country: 'US', :logo_content_type => nil)
            parent_customer.online_stores << online_store
            product = FactoryGirl.create(:product, customer_id: parent_customer.id,
                                         online_store_id: online_store.id,
                                         brand_owner: 'First Customer',
                                         country: 'US',
                                         rpc: "B00004TBJD",
                                         active: 1,
                                         url: 'http://test.com')
            get :export, :customer_id => parent_customer.name, :online_store_id => "", :format => :csv
            response.should redirect_to (:index)
            flash[:error].should eq("You can't export products for Standard Catalog Parent")
        end
        it "validate export when the customer is linked customer" do
            parent_customer = FactoryGirl.create(:customer, name: 'First Parent Customer US', is_standard_catalog_parent: true)
            linked_customer = FactoryGirl.create(:customer, name: 'First Customer US', standard_catalog_parent_id: parent_customer.id)
            online_store = FactoryGirl.create(:online_store, name: 'Amazon', country: 'US', :logo_content_type => nil)
            linked_customer.online_stores << online_store
            product = FactoryGirl.create(:product, customer_id: linked_customer.id,
                                         online_store_id: online_store.id,
                                         brand_owner: 'First Customer',
                                         country: 'US',
                                         rpc: "B00004TBJD",
                                         active: 1,
                                         url: 'http://test.com')
            get :export, :customer_id => linked_customer.name, :online_store_id => "", :format => :csv
            response.should redirect_to (:index)
            flash[:error].should eq("You can't export products for Linked Customer")
        end



    end

    describe "Put #Delete" do

        it "responds with 'Resource not found.'" do
            get :show, :id => '0', :customer_id => 'Clavis'
            response.should redirect_to("http://test.host/customers/Clavis/competitor_products")
            flash[:info].should eq("Resource not found.")

        end

    end


    describe "POST #preview" do

        let!(:customer) { FactoryGirl.create(:customer, :name => 'First Customer US') }
        let!(:customer_brand) {  FactoryGirl.create(:customer_brand, :name => 'Test brand', :customer_id => customer.id) }
        let!(:customer_category) { FactoryGirl.create(:customer_category, :name => 'Test category', :customer_id => customer.id) }
        let!(:online_store) { OnlineStore.where(name: 'ClavisStore', country: 'US').first }

        before(:each) do
            customer.online_stores << online_store
            manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'test manufacturer')
            8.times do |index|
                dimension = FactoryGirl.create(:dimension, :customer => customer, :label => "dimension#{index+1}", :name => "Test#{index+1}")
                FactoryGirl.create(:dimension_value, :dimension => dimension, :value => "dimension#{index+1}")
            end

            @file = fixture_file_upload('/files/competitor_products/competitor_products_different_case_dimensions.csv', 'text/csv')
            # Need to be mocked in the tests so it is not generating problems with transactions
            allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)
            post :preview, { :customer_id => customer.name, :file => @file}
            row = assigns(:rows).first
            expect(row["dimension3"]).to eq('dimension3')
            expect(CompetitorProduct.last.dimension3).to eq('dimension3')
            expect(response).to render_template("preview")
        end

        it "renders error when upload file with invalid header" do
            @file = fixture_file_upload('/files/competitor_products/competitor_products_invalid_header.csv', 'text/csv')
            post :preview, { :customer_id => customer.id, :file => @file}
            expect(flash[:error]).to eq("Error in csv file => The file is invalid. The following columns are missing: active")
            expect(response).to render_template("index")
        end

        it "renders error when upload file with active column invalid" do
            @file = fixture_file_upload('/files/competitor_products/competitor_products_active_invalid.csv', 'text/csv')
            post :preview, { :customer_id => customer.name, :file => @file}
            expect(flash[:error]).to eq("Error in csv file => active column value is incorrect in row : ClavisStore AU, B00000000. Valid values are 0 and 1")
            expect(response).to render_template("index")
        end

        context 'valid files' do

            it "successfully renders preview with valid file" do
                online_store = OnlineStore.where(:name => 'Test Store', :country => 'US')
                customer.online_stores << online_store

                @file = fixture_file_upload('/files/competitor_products/competitor_products.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                expect(response).to render_template("preview")
            end

            it "successfully renders preview with valid file even with different case dimension values." do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_different_case_dimensions.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                row = assigns(:rows).first
                expect(row["dimension3"]).to eq('dimension3')
                expect(CompetitorProduct.last.dimension3).to eq('dimension3')
                expect(response).to render_template("preview")
            end

            it "successfully renders preview with valid file having lookup_code." do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_having_lookup_code.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                row = assigns(:rows).first
                expect(row["lookup_code"]).to eq('RPC423123-12234')
                expect(response).to render_template("preview")
            end

            it "Gives error message that file is invalid as it is not having lookup_code." do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_not_having_lookup_code.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => The file is invalid. The following columns are missing: lookup_code")
                expect(response).to render_template("index")
            end

            it "successfully renders preview when duplicate records exist in Portfolio and Competitors table" do
                product = FactoryGirl.create(:product, customer_id: customer.id, rpc: 13456, online_store_id: online_store.id)
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 13457, online_store_id: online_store.id )
                @file = fixture_file_upload('/files/competitor_products/competitor_products_portfolio_duplicates.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                rows = assigns(:rows)
                product_duplicate = assigns(:product_duplicates)
                competitor_duplicate = assigns(:competitor_duplicates)

                expect(rows.size).to eq(3)
                expect(competitor_duplicate.size).to eq(1)
                expect(product_duplicate.size).to eq(1)
                expect(rows.first['rpc']).to eq('13456')
                expect(rows.first['retailer']).to eq(online_store.name)
                expect(product_duplicate.first[0]).to eq(online_store.name.downcase)
                expect(product_duplicate.first[1]).to eq(product.rpc.to_s)
                expect(competitor_duplicate.first[0]).to eq(online_store.name.downcase)
                expect(competitor_duplicate.first[1]).to eq(competitor_product.rpc.to_s)
            end

            it "successfully renders preview when upload file has a url and online store has scrape_code 'URL'" do
                online_store = OnlineStore.where(name: 'Store With Scrape Code URL', country: 'US').first
                customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_scrape_code_url_valid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)

                expect(rows.first['retailer']).to eq(online_store.name)
                expect(rows.first['rpc']).to eq('B00000012')
                expect(rows.first['gtin']).to eq('12345678901234')
                expect(rows.first['trusted_product_desc']).to eq('trusted description')
                expect(rows.first['brand']).to eq("Test brand")
                expect(rows.first['category']).to eq("Test category")
                expect(rows.first['dimension1']).to eq("dimension1")
                expect(rows.first['dimension2']).to eq("dimension2")
                expect(rows.first['dimension3']).to eq("dimension3")
                expect(rows.first['dimension4']).to eq("dimension4")
                expect(rows.first['dimension5']).to eq("dimension5")
                expect(rows.first['dimension6']).to eq("dimension6")
                expect(rows.first['dimension7']).to eq("dimension7")
                expect(rows.first['dimension8']).to eq("dimension8")
                expect(rows.first['msrp']).to eq("test msrp")
                expect(rows.first['min_price']).to eq("15")
                expect(rows.first['max_price']).to eq("25")
                expect(rows.first['url']).to eq("test url")
                expect(rows.first['manufacturer']).to eq("test manufacturer")
                expect(rows.first['country']).to eq("US")
                expect(rows.first['active']).to eq("1")
                expect(rows.first['status']).to eq("2")
            end

            it "successfully renders preview with blank dimension values" do
                (1..8).each do |i|
                    @file = fixture_file_upload("/files/competitor_products/competitor_products_product_dimension#{i}_blank.csv", 'text/csv')
                    post :preview, { :customer_id => customer.name, :file => @file}
                    expect(response).to render_template("preview")
                end
            end

            it "successfully renders preview with UNCATEGORIZED dimension values" do
                (1..8).each do |i|
                    @file = fixture_file_upload("/files/competitor_products/competitor_products_dimension#{i}_uncategorized.csv", 'text/csv')
                    post :preview, { :customer_id => customer.name, :file => @file}
                    expect(response).to render_template("preview")
                end
            end

            it "successfully renders preview and detects when there is a change to an existing products brand or category" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 13457, online_store_id: online_store.id, brand: 'Brand 1', category: 'Category 1', country: 'US')
                competitor_product_2 = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 13458, online_store_id: online_store.id, brand: 'test Brand', category: 'test Category', country: 'US')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_brand_category_change.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                competitor_product_changed = assigns(:changed_competitor_brand_category)

                expect(rows.size).to eq(2)
                expect(competitor_product_changed.size).to eq(2)
                expect(competitor_product_changed[0].size).to eq(2)
                expect(competitor_product_changed[1].size).to eq(2)

                # verify a word or character change has been detected
                expect(rows.first['brand']).to eq('Test brand')
                expect(competitor_product_changed.first[0][3]).to eq(competitor_product.brand)
                expect(competitor_product_changed.first[1][3]).to eq('Test brand')

                expect(rows.first['category']).to eq('Test category')
                expect(competitor_product_changed.first[0][4]).to eq(competitor_product.category)
                expect(competitor_product_changed.first[1][4]).to eq('Test category')

                # verify a case change has been detected
                expect(rows.second['brand']).to eq('Test brand')
                expect(competitor_product_changed.second[0][3]).to eq(competitor_product_2.brand)
                expect(competitor_product_changed.second[1][3]).to eq('Test brand')

                expect(rows.first['category']).to eq('Test category')
                expect(competitor_product_changed.second[0][4]).to eq(competitor_product_2.category)
                expect(competitor_product_changed.second[1][4]).to eq('Test category')
            end

            it "successfully renders preview and does not populate competitor_products_changed when there is no change to an existing products brand or category" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 13457, country: 'US', online_store_id: online_store.id, brand: 'Test brand', category: 'Test category')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_brand_category_change.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                competitor_product_changed = assigns(:changed_competitor_brand_category)

                expect(rows.size).to eq(2)
                expect(competitor_product_changed.size).to eq(0)
            end

            it "successfully renders preview and does populate competitor_products_changed if delete_from_db is not selected" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 13457, online_store_id: online_store.id, brand: 'Brand 1', category: 'Category 1')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_brand_category_change.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                competitor_product_changed = assigns(:changed_competitor_brand_category)

                expect(rows.size).to eq(2)
                expect(competitor_product_changed.size).to eq(1)
            end

            it "successfully renders preview and displays products To Be Added if delete_from_db is true" do
                @file = fixture_file_upload('/files/competitor_products/competitor_products.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(1)
                expect(record.new_competitor_rows.size).to eq(1)
                expect(record.new_competitor_rows_count).to eq(1)
                expect(record.updated_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(0)
                expect(record.new_competitor_rows_count).to eq(1)
            end

            it "successfully renders preview and displays products To Be Updated if delete_from_db is true" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 'B88888888', online_store_id: online_store.id, brand: 'Brand 1', category: 'Category 1', country: 'US')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_to_be_updated.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(1)
                expect(record.new_competitor_rows.size).to eq(1)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(1)
                expect(record.deleted_competitor_rows.size).to eq(1)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(0)
            end

            it "successfully renders preview and displays products To Be Updated and detects case change for RPC and URL if delete_from_db is true" do
                competitor_product = FactoryGirl.create(
                    :competitor_product, customer_id: customer.id, rpc: 'b88888888', gtin: '12345678901234', trusted_product_desc: 'trusted description', online_store_id: online_store.id, brand: 'Test brand', category: 'Test category',
                    dimension1: 'dimension1', dimension2: 'dimension2', dimension3: 'dimension3', dimension4: 'dimension4', dimension5: 'dimension5', dimension6: 'dimension6', dimension7: 'dimension7', dimension8: 'dimension8',
                    msrp: 'test msrp', min_price: '15', max_price: '25', url: 'TEST URL', manufacturer: 'test manufacturer', country: 'US', active: 1, status: 2)
                @file = fixture_file_upload('/files/competitor_products/competitor_products_to_be_updated.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(1)
                expect(record.new_competitor_rows.size).to eq(1)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(1)
                expect(record.updated_competitor_rows.first['rpc']).to eq('B88888888')
                expect(record.updated_competitor_rows.first['url']).to eq('test url')
                expect(record.deleted_competitor_rows.size).to eq(1)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(0)
            end

            it "successfully renders preview and displays products To Be Deleted if delete_from_db is true" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 'B88888887', country: 'US', online_store_id: online_store.id)
                competitor_product = FactoryGirl.create(
                    :competitor_product, customer_id: customer.id, rpc: 'B88888888', gtin: '1234', trusted_product_desc: 'description', online_store_id: online_store.id, brand: 'brand', category: 'category',
                    dimension1: 'dimension1', dimension2: 'dimension2', dimension3: 'dimension3', dimension4: 'dimension4', dimension5: 'dimension5', dimension6: 'dimension6', dimension7: 'dimension7', dimension8: 'dimension8',
                    msrp: '10', min_price: '15', max_price: '25', url: 'url', manufacturer: 'manufacturer', country: 'US', active: 1, status: 2)
                @file = fixture_file_upload('/files/competitor_products/competitor_products_to_be_deleted.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(0)
                expect(record.new_competitor_rows.size).to eq(0)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows.size).to eq(1)
                expect(record.deleted_competitor_rows_count).to eq(1)
                expect(record.unchanged_competitor_rows.size).to eq(1)
            end

            it "successfully renders preview and displays products Left Unchanged if delete_from_db is true" do
                competitor_product = FactoryGirl.create(
                    :competitor_product, customer_id: customer.id, rpc: 'B88888888', gtin: '1234', trusted_product_desc: 'description', online_store_id: online_store.id, brand: 'brand', category: 'category',
                    dimension1: 'dimension1', dimension2: 'dimension2', dimension3: 'dimension3', dimension4: 'dimension4', dimension5: 'dimension5', dimension6: 'dimension6', dimension7: 'dimension7', dimension8: 'dimension8',
                    msrp: '10', min_price: '15', max_price: '25', url: 'url', manufacturer: 'manufacturer', country: 'US', active: 1, status: 2)
                @file = fixture_file_upload('/files/competitor_products/competitor_products_unchanged.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(0)
                expect(record.new_competitor_rows.size).to eq(0)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(1)
            end

            it "successfully renders preview and detects when there is a change to an existing products gtin" do
                competitor_product = FactoryGirl.create(
                    :competitor_product, customer_id: customer.id, rpc: 'B00000000', gtin: '12345678901234', trusted_product_desc: 'trusted description', online_store_id: online_store.id, brand: 'Test brand', category: 'Test category',
                    dimension1: 'dimension1', dimension2: 'dimension2', dimension3: 'dimension3', dimension4: 'dimension4', dimension5: 'dimension5', dimension6: 'dimension6', dimension7: 'dimension7', dimension8: 'dimension8',
                    msrp: '12', min_price: '11', max_price: '14', url: 'www.test.com', manufacturer: 'test manufacturer', country: 'US', active: 1, status: 2)
                @file = fixture_file_upload('/files/competitor_products/competitor_products_gtin_blank.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(1)
                expect(record.new_competitor_rows.size).to eq(1)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(1)
                expect(record.updated_competitor_rows.first['gtin']).to eq(nil)
                expect(record.deleted_competitor_rows.size).to eq(1)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(0)
            end

            it "successfully renders preview and ignores changes to inactive dimensions" do
                competitor_product = FactoryGirl.create(
                    :competitor_product, customer_id: customer.id, rpc: 'B00000000', gtin: '12345678901234', trusted_product_desc: 'trusted description', online_store_id: online_store.id, brand: 'Test brand', category: 'Test category',
                    dimension1: 'test_dimension1', dimension2: 'test_dimension2', dimension3: 'test_dimension3', dimension4: 'UNCATEGORIZED', dimension5: 'UNCATEGORIZED', dimension6: 'UNCATEGORIZED', dimension7: 'UNCATEGORIZED', dimension8: 'UNCATEGORIZED',
                    msrp: '12', min_price: '11', max_price: '14', url: 'www.test.com', manufacturer: 'test manufacturer', country: 'US', active: 1, status: 2)

                customer.dimensions.delete_all
                (1..3).each do |index|
                    customer.dimensions << Dimension.new({ :label => "dimension#{index}", :name => "test_dimension#{index}" })
                end

                @file = fixture_file_upload('/files/competitor_products/competitor_products_inactive_dimension_changed.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}

                expect(response).to render_template('preview')
                rows = assigns(:rows)
                record = assigns(:record)

                expect(rows.size).to eq(0)
                expect(record.new_competitor_rows.size).to eq(0)
                expect(record.new_competitor_rows_count).to eq(0)
                expect(record.updated_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows.size).to eq(0)
                expect(record.deleted_competitor_rows_count).to eq(0)
                expect(record.unchanged_competitor_rows.size).to eq(1)
            end

            it "renders error when customer is standard parent" do
                parent_customer = FactoryGirl.create(:customer, name: 'Parent Customer US', is_standard_catalog_parent: true)
                online_store = FactoryGirl.create(:online_store, :name =>'ClavisStore', country: 'AU', logo_content_type: nil)
                parent_customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_to_be_updated.csv', 'text/csv')
                post :preview, { :customer_id => parent_customer.id, :file => @file}
                expect(flash[:error]).to eq("You can't preview products for Standard Catalog Parent")
                response.should redirect_to (:index)
            end

            it "renders error when customer is linked customer" do
                parent_customer = FactoryGirl.create(:customer, name: 'Parent Customer US', is_standard_catalog_parent: true)
                linked_customer = FactoryGirl.create(:customer, name: 'Linked Customer US', standard_catalog_parent_id: parent_customer.id)
                online_store = FactoryGirl.create(:online_store, :name =>'ClavisStore', country: 'AU', logo_content_type: nil)
                linked_customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_to_be_updated.csv', 'text/csv')
                post :preview, { :customer_id => linked_customer.id, :file => @file}
                expect(flash[:error]).to eq("You can't preview products for Linked Customer")
                response.should redirect_to (:index)
            end
        end

        context 'invalid files' do
            it "renders error with correct csv index when brand is invalid and there are duplicates." do
                # this tests that the index is still correct when duplicate records are removed from array of records in upload
                product = FactoryGirl.create(:product, customer_id: customer.id, rpc: 13456, online_store_id: online_store.id)
                competitor_product = FactoryGirl.create(:competitor_product, country: 'US', customer_id: customer.id, rpc: 13457, online_store_id: online_store.id )
                @file = fixture_file_upload('/files/competitor_products/competitor_products_portfolio_duplicates_invalid_brand.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => brand value 'Invalid brand' is not valid in row : ClavisStore US, 13458")
                expect(response).to render_template("index")

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}
                expect(flash[:error]).to eq("Error in csv file => brand value 'Invalid brand' is not valid in row : ClavisStore US, 13458")
                expect(response).to render_template("index")
            end
            it "renders error when upload file with invalid header" do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_invalid_header.csv', 'text/csv')
                post :preview, { :customer_id => customer.id, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => The file is invalid. The following columns are missing: active")
                expect(response).to render_template("index")
            end

            it "renders error when upload file with active column invalid" do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_active_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => active column value is incorrect in row : ClavisStore AU, B00000000. Valid values are 0 and 1")
                expect(response).to render_template("index")

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file}
                expect(flash[:error]).to eq("Error in csv file => active column value is incorrect in row : ClavisStore AU, B00000000. Valid values are 0 and 1")
                expect(response).to render_template("index")
            end

            it "renders error when upload file has duplicate values" do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_duplicate_values.csv', 'text/csv')
                post :preview, { :customer_id => customer.id, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => duplicated entries at rows 3")
                expect(response).to render_template("index")

                post :preview, { :customer_id => customer.id, :delete_from_db => 'true', :file => @file}
                expect(flash[:error]).to eq("Error in csv file => duplicated entries at rows 3")
                expect(response).to render_template("index")
            end

            it 'renders error when upload file has invalid brand' do
                online_store = FactoryGirl.create(:online_store, :name => "Test Store", :country => "AU", :logo_content_type => nil)
                customer.online_stores << online_store

                @file = fixture_file_upload('/files/competitor_products/competitor_products_brand_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq("Error in csv file => brand value 'invalid' is not valid in row : ClavisStore US, B00000000")
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq("Error in csv file => brand value 'invalid' is not valid in row : ClavisStore US, B00000000")
                expect(response).to render_template('index')
            end

            it 'renders error when upload file has blank brand value' do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_brand_blank.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => brand value is blank in row : ClavisStore US, B00000000')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => brand value is blank in row : ClavisStore US, B00000000')
                expect(response).to render_template('index')
            end

            it 'renders error when upload file has invalid status value' do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_tracking_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => status column value is incorrect in row : ClavisStore US, B00000000. Valid values are 1 or 2')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => status column value is incorrect in row : ClavisStore US, B00000000. Valid values are 1 or 2')
                expect(response).to render_template('index')
            end

            it 'renders error when upload file has blank status value' do
                online_store = FactoryGirl.create(:online_store, :name => 'Test Store', :country => 'AU', :logo_content_type => nil)
                customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_tracking_blank.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => status column value is incorrect in row : ClavisStore US, B00000000. Valid values are 1 or 2')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => status column value is incorrect in row : ClavisStore US, B00000000. Valid values are 1 or 2')
                expect(response).to render_template('index')
            end

            it 'renders error when upload file has invalid category' do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_category_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq("Error in csv file => category value 'invalid' is not valid in row : ClavisStore US, B00000000")
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq("Error in csv file => category value 'invalid' is not valid in row : ClavisStore US, B00000000")
                expect(response).to render_template('index')
            end

            it 'renders error when upload file has blank category value' do
                online_store = FactoryGirl.create(:online_store, :name => 'Test Store', :country => 'AU', :logo_content_type => nil)
                customer.online_stores << online_store

                @file = fixture_file_upload('/files/competitor_products/competitor_products_category_blank.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => category value is blank in row : ClavisStore US, B00000000')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => category value is blank in row : ClavisStore US, B00000000')
                expect(response).to render_template('index')
            end

            it 'renders error when upload has not valid dimension value' do
                @file = fixture_file_upload('/files/competitor_products/competitor_products_dimension_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => dimension1 value \'dimensionX\' not valid. row : ClavisStore US, B00000000. Valid values: dimension1, UNCATEGORIZED')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => dimension1 value \'dimensionX\' not valid. row : ClavisStore US, B00000000. Valid values: dimension1, UNCATEGORIZED')
                expect(response).to render_template('index')
            end

            it "renders error when upload file has missing url and online store has scrape_code 'URL'" do
                customer = FactoryGirl.create(:customer, name: 'Test Customer US')
                online_store = OnlineStore.where(name: 'Store With Scrape Code URL', country: 'US').first
                customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_scrape_code_missing_url_invalid.csv', 'text/csv')
                post :preview, { :customer_id => customer.id, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => Store Scrape Code is 'URL' but url field is blank in row : Store With Scrape Code URL US, B00000012")
                expect(response).to render_template("index")

                post :preview, { :customer_id => customer.id, :delete_from_db => 'true', :file => @file}
                expect(flash[:error]).to eq("Error in csv file => Store Scrape Code is 'URL' but url field is blank in row : Store With Scrape Code URL US, B00000012")
                expect(response).to render_template("index")
            end

            it 'renders error when upload file has blank product description value' do
                online_store = FactoryGirl.create(:online_store, :name => 'Test Store', :country => 'AU', :logo_content_type => nil)
                customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_product_description_blank.csv', 'text/csv')
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => trusted_product_desc value cannot be blank .. row : ClavisStore US, B00000000')
                expect(response).to render_template('index')

                post :preview, { :customer_id => customer.name, :delete_from_db => 'true', :file => @file }
                expect(flash[:error]).to eq('Error in csv file => trusted_product_desc value cannot be blank .. row : ClavisStore US, B00000000')
                expect(response).to render_template('index')
            end

            it "renders error when upload file has online_stores not associated to a customer when delete_all is selected" do
                online_store = FactoryGirl.create(:online_store, :name =>'ClavisStore', country: 'AU', logo_content_type: nil)
                customer.online_stores << online_store
                @file = fixture_file_upload('/files/competitor_products/competitor_products_with_non_existing_store.csv', 'text/csv')
                post :preview, { :customer_id => customer.id, :file => @file, :delete_from_db => 'true'}
                expect(flash[:error]).to eq("Error in csv file => Online Store: ClavisStoreXYZ is not linked to this customer.")
                expect(response).to render_template("index")
            end
        end
    end

    describe "POST #create" do

        before do
            ApplicationController.any_instance.stub(:pim_update_candidates).and_return([true, ''])
        end

        context 'records are valid' do
            let(:customer) {  FactoryGirl.create(:customer, :name => "Any_Customer") }
            let(:online_store) { FactoryGirl.create(:online_store, :name => "Test_store", :country => "FR", :logo_content_type => nil) }

            it "successfully creates valid record" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq("Number of records successfully added: 1")
                response.should redirect_to (:index)
            end

            it "successfully updates valid record when delete_all is FALSE" do
                customer.online_stores << online_store
                csv_rows = [{"retailer"=>"Test_store", "country"=>"FR", "rpc"=>"95898", "manufacturer"=>"Test Manufacturer", "active"=>"1"}]
                post :create, :customer_id => customer.name, :to_be_updated => csv_rows.to_json, :to_be_updated_count => '1', :delete_all => ''
                expect(flash[:success]).to eq("Number of records added: 0 | Number of records updated: 1")
                response.should redirect_to (:index)
            end

            it "successfully creates valid record -- trailing spaces removed" do
                customer.online_stores << online_store
                category = FactoryGirl.create(:customer_category, customer_id: customer.id, name: 'Test Category')
                brand = FactoryGirl.create(:customer_brand, customer_id: customer.id, name: 'Test Brand')
                manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'test manufacturer')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_white_space.csv', 'text/csv')
                # Need to be mocked in the tests so it is not generating problems with transactions
                allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)
                post :preview, { :customer_id => 'Any_Customer', :file => @file}
                expect(response).to render_template("preview")
                csv_rows = assigns(:rows).to_json

                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq("Number of records successfully added: 1")
                response.should redirect_to (:index)

                customer.competitor_products.first.attributes.values.each { |value| expect(value.length).to eq(value.squish.length) if value.respond_to?('squish')}
            end

            it "successfully creates valid record -- and change case for manufacturer" do
                customer.online_stores << online_store
                category = FactoryGirl.create(:customer_category, customer_id: customer.id, name: 'Test Category')
                brand = FactoryGirl.create(:customer_brand, customer_id: customer.id, name: 'Test Brand')
                manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'Test Manufacturer')
                @file = fixture_file_upload('/files/competitor_products/competitor_products_manufacturer_different_case.csv', 'text/csv')
                # Need to be mocked in the tests so it is not generating problems with transactions
                allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)
                post :preview, { :customer_id => 'Any_Customer', :file => @file}
                expect(response).to render_template("preview")
                csv_rows = assigns(:rows).to_json

                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq("Number of records successfully added: 1")
                response.should redirect_to (:index)
                expect(customer.competitor_products.first.manufacturer).to eq('Test Manufacturer')
            end

            it 'renders error when upload has not valid manufacturer value' do
                customer.online_stores << online_store
                FactoryGirl.create(:customer_brand, :name => 'Test brand', :customer_id => customer.id)
                FactoryGirl.create(:customer_category, :name => 'Test category', :customer_id => customer.id)
                manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'test manufacturer')
                8.times do |index|
                    dimension = FactoryGirl.create(:dimension, :customer => customer, :label => "dimension#{index+1}", :name => "Test#{index+1}")
                    FactoryGirl.create(:dimension_value, :dimension => dimension, :value => "dimension#{index+1}")
                end
                @file = fixture_file_upload('/files/competitor_products/competitor_products_manufacturer_invalid.csv', 'text/csv')
                # Need to be mocked in the tests so it is not generating problems with transactions
                allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => manufacturer value is not valid in row : Test_store FR, B00000000')
                expect(response).to render_template('index')
            end

            it 'renders error when upload has a blank manufacturer value' do
                customer.online_stores << online_store
                FactoryGirl.create(:customer_brand, :name => 'Test brand', :customer_id => customer.id)
                FactoryGirl.create(:customer_category, :name => 'Test category', :customer_id => customer.id)
                manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'test manufacturer')
                8.times do |index|
                    dimension = FactoryGirl.create(:dimension, :customer => customer, :label => "dimension#{index+1}", :name => "Test#{index+1}")
                    FactoryGirl.create(:dimension_value, :dimension => dimension, :value => "dimension#{index+1}")
                end
                @file = fixture_file_upload('/files/competitor_products/competitor_products_manufacturer_blank.csv', 'text/csv')
                # Need to be mocked in the tests so it is not generating problems with transactions
                allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)
                post :preview, { :customer_id => customer.name, :file => @file }
                expect(flash[:error]).to eq('Error in csv file => manufacturer value cannot be blank .. row : Test_store FR, B00000000')
                expect(response).to render_template('index')
            end

            it "successfully creates valid record with status field set to 1" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\", \"status\":\"1\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq('Number of records successfully added: 1')
                expect(customer.competitor_products.first.status).to eq(1)
                response.should redirect_to (:index)
            end

            it "successfully creates valid record with status field set to 0" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"958980\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\", \"tracking\":\"0\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq('Number of records successfully added: 1')
                expect(customer.competitor_products.first.status).to eq(0)
                response.should redirect_to (:index)
            end

            it "successfully creates valid record with status field set to 2" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\", \"status\":\"2\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''

                expect(flash[:success]).to eq("Number of records successfully added: 1")
                expect(customer.competitor_products.first.status).to eq(2)
                response.should redirect_to (:index)
            end

            it 'does not render error when customer candidates update via cpc endpoint succeeds' do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"958543\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:success]).to eq("Number of records successfully added: 1")
                response.should redirect_to (:index)
                expect(flash[:error]).to be nil
            end

            it "successfully creates valid record when delete_all is true" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :to_be_deleted_count => '0', :to_be_updated_count => '0', :delete_all => 'true'
                expect(flash[:success]).to eq("Number of records added: 1 | Number of records updated: 0 | Number of records deleted: 0")
                response.should redirect_to (:index)
            end

            it "successfully updates valid record when delete_all is true" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '0', :to_be_deleted_count => '0', :to_be_updated_count => '1', :delete_all => 'true'
                expect(flash[:success]).to eq("Number of records added: 0 | Number of records updated: 1 | Number of records deleted: 0")
                response.should redirect_to (:index)
            end

            it "successfully deletes valid record when delete_all is true" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\"}]"
                post :create, :customer_id => customer.name, :to_be_deleted => csv_rows, :to_be_added_count => '0', :to_be_deleted_count => '1', :to_be_updated_count => '0', :delete_all => 'true'
                expect(flash[:success]).to eq("Number of records added: 0 | Number of records updated: 0 | Number of records deleted: 1")
                response.should redirect_to (:index)
            end

            it "returns correct error message when it can't find the online_store to delete" do
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\"}]"
                post :create, :customer_id => customer.name, :to_be_deleted => csv_rows, :to_be_added_count => '0', :to_be_deleted_count => '1', :to_be_updated_count => '0', :delete_all => 'true'
                expected_error_message = "Error in csv file => You are trying to delete a product from store 'Test_store FR' which is no longer configured for this customer, please reconfigure. There is mismatch between the stores configured in metadata and the competitor list."
                expect(flash[:error]).to eq(expected_error_message)
                response.should redirect_to (:index)
            end
        end

        context 'records are invalid' do
            let(:customer) {  FactoryGirl.create(:customer, :name => "Any_Customer") }
            let(:online_store) { FactoryGirl.create(:online_store, :name => "Test_store", :country => "FR", :logo_content_type => nil) }

            it 'renders database error when a value has an invalid format' do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"958980\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\", \"tracking\":\"0\", \"msrp\":\"5.38 - 15.61\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :delete_all => ''
                expect(flash[:error]).to eq("Error in csv file => Data too long for column 'msrp' at row 1")
                response.should redirect_to (:index)
            end

            it 'renders error when updating customer candidates via cpc endpoint fails' do
                customer.online_stores << online_store
                ApplicationController.any_instance.stub(:pim_update_candidates).and_return([false, 'Number of records successfully added: 1 but trusted source update failed. Please contact Clavis support.'])
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"958980\", \"manufacturer\":\"Test Manufacturer\", \"active\":\"1\", \"tracking\":\"0\", \"msrp\":\"5.38\"}]"
                post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                expect(flash[:error]).to eq('Number of records successfully added: 1 but PIM update failed. Please contact Clavis support.')
                response.should redirect_to (:index)
            end
            it "successfully creates valid records with default dimension values" do
                online_store = OnlineStore.where(name: 'ClavisStore', country: 'US').first
                customer.online_stores << online_store
                category = FactoryGirl.create(:customer_category, customer_id: customer.id, name: 'Test category')
                brand = FactoryGirl.create(:customer_brand, customer_id: customer.id, name: 'Test brand')
                manufacturer = FactoryGirl.create(:manufacturer, customer_id: customer.id, name: 'Test manufacturer')
                # Need to be mocked in the tests so it is not generating problems with transactions
                allow_any_instance_of(ProductPreviewer).to receive(:create_index_in_competitors_temp_table).and_return(true)

                (1..8).each do |i|
                    @file = fixture_file_upload("/files/competitor_products/competitor_products_product_dimension#{i}_blank.csv", 'text/csv')
                    post :preview, { :customer_id => customer.name, :file => @file}

                    expect(response).to render_template("preview")

                    csv_rows = assigns(:rows).to_json
                    post :create, :customer_id => customer.name, :to_be_added => csv_rows, :to_be_added_count => '1', :delete_all => ''
                    expect(flash[:success]).to eq("Number of records successfully added: 1")
                    response.should redirect_to (:index)
                    expect(eval("CompetitorProduct.last.dimension#{i}")).to eq("UNCATEGORIZED")

                    (1..8).each do |j|
                        expect(eval("CompetitorProduct.last.dimension#{j}")).to eq("UNCATEGORIZED") unless j == i
                    end
                end
            end
        end
    end

    describe "POST #delete_preview" do

        let!(:customer) { FactoryGirl.create(:customer, :name => 'First Customer US') }
        let!(:online_store) { OnlineStore.where(name: 'ClavisStore', country: 'US').first }

        before(:each) do
            customer.online_stores << online_store
        end

        context 'valid files' do

            it "successfully renders delete preview with valid file" do
                @file = fixture_file_upload('/files/competitor_products/competitor_products.csv', 'text/csv')
                post :delete_preview, { :customer_id => customer.name, :file => @file}

                expect(response).to render_template("delete_preview")
            end

            it "successfully renders delete preview with valid file and identifies products_to_delete & products_not_found" do
                competitor_product = FactoryGirl.create(:competitor_product, customer_id: customer.id, rpc: 134578646, online_store_id: online_store.id )

                @file = fixture_file_upload('/files/competitor_products/competitor_products_delete_valid.csv', 'text/csv')
                post :delete_preview, { :customer_id => customer.name, :file => @file}

                expect(response).to render_template("delete_preview")

                products_to_delete = assigns(:products_to_delete)
                products_not_found = assigns(:products_not_found)

                expect(products_to_delete.size).to eq(1)
                expect(products_not_found.size).to eq(1)
            end

            it "Validate delete preview with valid file when the customer is standard catalog parent" do
                parent_customer = FactoryGirl.create(:customer, :name => 'New_Parent_Customer_1', is_standard_catalog_parent: true)

                @file = fixture_file_upload('/files/competitor_products/competitor_products_delete_valid.csv', 'text/csv')
                post :delete_preview, { :customer_id => parent_customer.name, :file => @file}

                response.should redirect_to (:index)
                flash[:error].should eq("You can't delete_preview products for Standard Catalog Parent")
            end

            it "Validate delete preview with valid file when the customer is standard catalog parent" do
                parent_customer = FactoryGirl.create(:customer, :name => 'New_Parent_Customer_1', is_standard_catalog_parent: true)
                linked_customer = FactoryGirl.create(:customer, :name => 'New_Linked_Customer_1', standard_catalog_parent_id: parent_customer.id)

                @file = fixture_file_upload('/files/competitor_products/competitor_products_delete_valid.csv', 'text/csv')
                post :delete_preview, { :customer_id => linked_customer.name, :file => @file}

                response.should redirect_to (:index)
                flash[:error].should eq("You can't delete_preview products for Linked Customer")
            end

        end

        context 'invalid files' do
            it "renders error when upload file with invalid header" do
                # file missing country header
                @file = fixture_file_upload('/files/competitor_products/competitor_products_delete_invalid_header.csv', 'text/csv')
                post :delete_preview, { :customer_id => customer.name, :file => @file}
                expect(flash[:error]).to eq("Error in csv file => The file is invalid. The following columns are missing: country")
                response.should redirect_to (:index)
            end
        end
    end

    describe "POST #delete" do
        context 'records are valid' do
            let(:customer) {  FactoryGirl.create(:customer, :name => "Any_Customer") }
            let(:online_store) { FactoryGirl.create(:online_store, :name => "Test_store", :country => "FR", :logo_content_type => nil) }

            it "successfully deletes valid record" do
                customer.online_stores << online_store
                csv_rows =
                    "[{\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95898\"}, {\"retailer\":\"Test_store\",\"country\":\"FR\",\"rpc\":\"95899\"}]"
                post :delete, :customer_id => customer.name, :to_be_deleted => csv_rows
                expect(flash[:success]).to eq("Number of records successfully deleted: 2")
                response.should redirect_to (:index)
            end
        end
    end

    describe "POST #validate_classification_hierarchy" do
        let!(:customer) { FactoryGirl.create(:customer, :name => 'First Customer US') }
        let!(:customer_brand) {  FactoryGirl.create(:customer_brand, :name => 'Test brand', :customer_id => customer.id) }
        let!(:customer_category) { FactoryGirl.create(:customer_category, :name => 'Test category', :customer_id => customer.id) }
        let!(:online_store) { OnlineStore.where(name: 'ClavisStore', country: 'US').first }
        let!(:setting) { FactoryGirl.create(:customer_setting, :setting_name => 'classification_hierarchy_enabled',:default_value => "1") }
        let!(:customer_setting_value) {FactoryGirl.create(:customer_setting_value, :customer_id => customer.id, :customer_setting_id => setting.id, value: true) }
        let!(:uid) {'e974c5c0-1f9e-4444-abf9-03f1b9296565'}

        it "gives json response error when upload file with invalid header" do
            @file = fixture_file_upload('/files/competitor_products/competitor_products_invalid_header.csv', 'text/csv')
            post :validate_classification_hierarchy, { :customer_id => customer.id, :file => @file, :format => :json}
            res = JSON.parse(response.body)
            expect(res["error"]).to eq("Error in csv file => The file is invalid. The following columns are missing: active")
        end

        it 'should make a request with the correct arguments for PIM API' do
            allow(HierarchyValidations).to receive(:generate_request_id).and_return("12323456432")
            request_id = HierarchyValidations.send(:generate_request_id)
            allow(RestClient::Request).to receive(:execute)
            .with(pim_validate_classification_api( request_id,customer.id))
            .and_return({ "uid" => uid }.to_json)
            @file = fixture_file_upload('/files/competitor_products/competitor_products.csv', 'text/csv')
            post :validate_classification_hierarchy, { :customer_id => customer.id, :file => @file, :format => :json}
            res = JSON.parse(response.body)
            expect(res["uid"]).to eq(uid)
            expect(res["action_method"]).to eq("IMPORT")
        end

        it "async validate classification hierarchy status with action method 'IMPORT' on validation error" do
            allow(HierarchyValidations).to receive(:generate_request_id).and_return("12323456432")
            request_id = HierarchyValidations.send(:generate_request_id)
            allow(RestClient::Request).to receive(:execute)
            .with(pim_validate_async_processing_status_api(uid))
            .and_return({'status_name' => 'FAILED', 'error_message' => 'Failed'}.to_json)
            get :validate_classification_hierarchy_status, { :customer_id => customer.id, :uid => uid, :format => :json }
            res = JSON.parse(response.body)
            expect(res['s3_url']).to include('competitors_validation_log')
            expect(res['s3_url']).to include('X-Amz-Signature')
        end

    end

    def pim_validate_classification_api(request_id, customer_id)
        {
            method: :get,
            url:  "#{CONFIG['pim_api_url']}/api/products/validateHierarchy",
                headers: {
                    Authorization: "Bearer #{CONFIG['pim_api_token']}",
                    params: {
                        request_id: request_id,
                        customer_id: customer_id
                    }
                }
        }
    end

    def pim_validate_async_processing_status_api(uid)
        {
            method: :get,
            url:  "#{CONFIG['pim_api_url']}/api/ctl/asyncProcessing/#{uid}",
                headers: {
                    Authorization: "Bearer #{CONFIG['pim_api_token']}"
                }
        }
    end


end
