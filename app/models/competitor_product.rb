# == Schema Information
#
# Table name: competitor_products
#
#  id                   :integer          not null, primary key
#  customer_id          :integer
#  online_store_id      :integer
#  rpc                  :string(20)
#  gtin                 :string(20)
#  trusted_product_desc :text
#  brand                :string(60)
#  category             :string(255)
#  dimension1           :string(255)
#  dimension2           :string(255)
#  dimension3           :string(255)
#  dimension4           :string(255)
#  dimension5           :string(255)
#  dimension6           :string(255)
#  dimension7           :string(255)
#  dimension8           :string(255)
#  msrp                 :string(10)
#  min_price            :string(10)
#  max_price            :string(10)
#  url                  :string(2000)
#  manufacturer         :string(60)
#  country              :string(2)
#

require 'csv'

class CompetitorProduct < Base

    belongs_to :customer, foreign_key: "customer_id"
    belongs_to :online_store

    def self.select_all(params)
        cloned_params = params.clone
        cloned_params[:created_updated] = get_created_updated(params)

        cache_key = generate_cache_key('CompetitorProduct', cloned_params)

        Rails.cache.fetch(cache_key) do
            filters = get_filters(params)

            # There can be 10's of thousands of rows returned here so by manually building the query and running it direct
            # it avoids using ActiveRecord objects so the json rendering is much faster on large data sets (SSENG-126)

            query = "SELECT competitor_products.*, customers.name
                AS customer_name FROM competitor_products
                INNER JOIN customers ON customers.id = competitor_products.customer_id WHERE"

            filters.each_with_index  do | (key,value), index |
                query << " AND" if index > 0
                query << " competitor_products.#{key} = #{value}"
            end

            records = ActiveRecord::Base.connection.select_all(query).to_a

            records = records.to_json if params[:format] == 'json'
        end
    end

    private_class_method def self.get_filters(params)
    if params[:customer_id] && params[:online_store_id]
        {
            status: 1,
            customer_id: params[:customer_id],
            online_store_id: params[:online_store_id]
        }
    elsif params[:online_store_id]
        {
            status: 1,
            online_store_id: params[:online_store_id]
        }.delete_if{ |k,v| k == :status && params[:all] }
    else
        {
            status: 1,
            customer_id: params[:customer_id]
        }
    end
end

private_class_method def self.get_created_updated(params)
result = self.where(get_filters(params)).select("MAX(updated_at) AS updated_at, MAX(created_at) AS created_at").first
created_updated = result.created_at.to_s << ' ' << result.updated_at.to_s
created_updated.downcase.gsub(/\s/,'-')
end

def self.delete_all_for_customer(customer_id, username)

    count = CompetitorProduct.where(customer_id: customer_id).count
    query = "UPDATE competitor_products SET updated_by = #{ActiveRecord::Base::sanitize(username)} where customer_id = #{customer_id}"
    sql = "DELETE FROM competitor_products WHERE customer_id=#{customer_id}"

    begin
        ActiveRecord::Base.connection.execute(query)
        ActiveRecord::Base.connection.delete(sql)
    rescue StandardError => e
        return [false, e.to_s]
    end

    if count > 0
        sql = "INSERT INTO audits (auditable_type, associated_id, username, action, audited_changes, created_at)
                                VALUES ('CompetitorProduct', '#{customer_id}', #{ActiveRecord::Base.sanitize(username)}, 'Delete', '#{count}','#{Date.today}')"
        begin
            ActiveRecord::Base.connection.execute(sql)
        rescue StandardError => e
            logger.error 'Error deleting competitor products ' + e.to_s
        end
    end

    [true, '']

end

def self.delete_some_for_customer!(record_list, customer_id, username)
    raise ArgumentError "record_list not an Array of Hashes" unless record_list.is_a?(Array) && record_list.all? {|rec| rec.is_a? Hash }
    return record_list if record_list.empty?

    (1..record_list.count).step(10000).each do |start|
        key_list = record_list[start-1..start+9998].map(&:keys).flatten.map(&:to_s).uniq.sort
        value_list = record_list[start-1..start+9998].map do |rec|
            list = []
            key_list.each {|key| list <<  ActiveRecord::Base.connection.quote(rec[key] || rec[key.to_sym]) }
            list
        end
        where_query = "WHERE (#{key_list.join(", ")}) IN (#{value_list.map {|rec| "(#{rec.join(", ")})" }.join(" ,")})"
        query = "UPDATE competitor_products SET updated_by = #{ActiveRecord::Base::sanitize(username)} #{where_query}"
        sql = "DELETE FROM competitor_products #{where_query}"

        begin
            ActiveRecord::Base.connection.execute(query)
            ActiveRecord::Base.connection.delete(sql)
        rescue StandardError => e
            logger.error e.original_exception.to_s
            return [false, e.original_exception.to_s]
        end
    end

    sql = "INSERT INTO audits (auditable_type, associated_id, username, action, audited_changes, created_at)
                VALUES ('CompetitorProduct', '#{customer_id}', #{ActiveRecord::Base.sanitize(username)}, 'Delete', '#{record_list.size}','#{Date.today}')"
    begin
        ActiveRecord::Base.connection.execute(sql)
    rescue StandardError => e
        logger.error 'Error deleting competitor products ' + e.to_s
    end

    return [true, ""]
end

def self.import!(record_list, customer_id, username)
    raise ArgumentError "record_list not an Array of Hashes" unless record_list.is_a?(Array) && record_list.all? {|rec| rec.is_a? Hash }
    return record_list if record_list.empty?

    (1..record_list.count).step(1000).each do |start|
        key_list, value_list = convert_record_list(record_list[start-1..start+998], username)
        sql = "INSERT INTO #{self.table_name} (#{key_list.join(", ")}) VALUES #{value_list.map {|rec| "(#{rec.join(", ")})" }.join(" ,")}"
        begin
            self.connection.insert_sql(sql)
        rescue StandardError => e
            logger.error e.original_exception.to_s
            return [false, e.original_exception.to_s]
        end

    end

    sql = "INSERT INTO audits (auditable_type, associated_id, username, action, audited_changes, created_at)

                             VALUES ('CompetitorProduct', '#{customer_id}', #{ActiveRecord::Base.sanitize(username)},'Create','#{record_list.size}', '#{Date.today}')"
    begin
        self.connection.insert_sql(sql)
    rescue StandardError => e
        logger.error e.original_exception.to_s
    end

    return [true, ""]
end

def self.convert_record_list(record_list, username)
    # Build the list of keys

    key_list = record_list.map(&:keys).flatten.map(&:to_s).uniq.sort

    value_list = record_list.map do |rec|
        list = []
        key_list.each {|key| list <<  ActiveRecord::Base.connection.quote(rec[key] || rec[key.to_sym]) }
        list
    end

    # If table has standard timestamps and they're not in the record list then add them to the record list
    time = ActiveRecord::Base.connection.quote(Time.now)
    for field_name in %w(created_at)
        if self.column_names.include?(field_name) && !(key_list.include?(field_name))
            key_list << field_name
            value_list.each {|rec| rec << time }
        end
    end

    for field_name in %w(created_by)
        if self.column_names.include?(field_name) && !(key_list.include?(field_name))
            key_list << field_name
            value_list.each {|rec| rec << ActiveRecord::Base.sanitize(username)}
        end
    end
    return [key_list, value_list]
end

end
