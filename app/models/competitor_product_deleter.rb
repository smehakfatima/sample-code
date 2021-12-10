class CompetitorProductDeleter
    include ActiveModel::Validations
    extend ActiveModel::Naming

    attr_reader :errors, :deleted_count

    def initialize(customer, rows, username)
        @customer = customer
        @rows = rows || '{}'
        @errors = ActiveModel::Errors.new(self)
        @deleted_count=0
        @username = username
    end

    def delete
        res, msg = apply_csv_data
    end

    private

    def apply_csv_data
        @customer_online_stores = @customer.online_stores
        records_to_delete = []

        JSON.parse(@rows).each do |row|
            online_store = @customer_online_stores.find{ |online_store| online_store[:name].downcase === row['retailer'].downcase and online_store[:country].downcase == row['country'].downcase}

            unless online_store
                return [false, "You are trying to delete a product from store '#{row['retailer']} #{row['country']}' which is no longer configured for this customer, please reconfigure. There is mismatch between the stores configured in metadata and the competitor list."]
            end

            records_to_delete << {
                :customer_id => @customer.id,
                :online_store_id => online_store.id,
                :country => row['country'],
                :rpc => row['rpc']
            }
        end

        @deleted_count = records_to_delete.size

        return true if records_to_delete.size == 0

        msg, error = CompetitorProduct.delete_some_for_customer!(records_to_delete, @customer.id, @username)
        [msg, error]
    end
end
