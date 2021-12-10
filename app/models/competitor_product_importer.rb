class CompetitorProductImporter
    include ActiveModel::Validations
    extend ActiveModel::Naming

    attr_reader :errors, :added_count

    DIMENSION_DEFAULT_VALUE = 'UNCATEGORIZED'

    def initialize(customer, rows, username)
        @customer = customer
        @rows = rows || '{}'
        @errors = ActiveModel::Errors.new(self)
        @added_count=0
        @username = username

    end

    def import
        res, msg = apply_csv_data
    end

    private

    def apply_csv_data

        @customer_online_stores = @customer.online_stores
        new_records = []

        JSON.parse(@rows).each do |row|

            online_store = @customer_online_stores.find{ |online_store| online_store[:name].downcase === row['retailer'].downcase and online_store[:country].downcase == row['country'].downcase}

            new_records << {:customer_id => @customer.id,
                            :online_store_id => online_store.id,
                            :country => row['country'],
                            :rpc => row['rpc'],
                            :gtin=>row['gtin'],
                            :trusted_product_desc => row['trusted_product_desc'],
                            :brand => row['brand'],
                            :category => row['category'],
                            :msrp => row['msrp'],
                            :min_price => row['min_price'],
                            :max_price => row['max_price'],
                            :url => row['url'],
                            :manufacturer => row['manufacturer'],
                            :dimension1 => row['dimension1'] || DIMENSION_DEFAULT_VALUE,
                            :dimension2 => row['dimension2'] || DIMENSION_DEFAULT_VALUE,
                            :dimension3 => row['dimension3'] || DIMENSION_DEFAULT_VALUE,
                            :dimension4 => row['dimension4'] || DIMENSION_DEFAULT_VALUE,
                            :dimension5 => row['dimension5'] || DIMENSION_DEFAULT_VALUE,
                            :dimension6 => row['dimension6'] || DIMENSION_DEFAULT_VALUE,
                            :dimension7 => row['dimension7'] || DIMENSION_DEFAULT_VALUE,
                            :dimension8 => row['dimension8'] || DIMENSION_DEFAULT_VALUE,
                            :active => row['active'].to_i,
                            :status => row['status'].to_i,
                            :lookup_code => row['lookup_code']

                            }

        end

        @added_count = new_records.size

        return true if new_records.size == 0

        msg, error = CompetitorProduct.import!(new_records, @customer.id, @username)

        [msg, error]

    end

end
