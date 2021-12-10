class CSVImporter
  include ActiveModel::Validations
  extend ActiveModel::Naming

  attr_reader :errors,:added_count, :deleted_count

  def initialize(customer,to_be_added, to_be_deleted)
    @customer = customer
    @to_be_added =to_be_added
    @to_be_deleted =to_be_deleted

    @errors = ActiveModel::Errors.new(self)
    @added_count=0
    @deleted_count=0
  end

  def import()
    apply_import_added
    apply_import_deleted
  end

  private


  def apply_import_added()
    if @to_be_added.any?


      @to_be_added.each do |title, rows|
        field_def=CSVMapping.mapping_ui_title_to_relationship[title]
        rows.each do |key, row|
          record = field_def['class'].where(row).first
          if record.nil?
            record=field_def['class'].create(row)
          end
          records = @customer.send(field_def['customer_has_many_field'])
          if !(records.include? record)
            records << record
            @added_count+=1
          end
        end
      end
    end
  end

  def apply_import_deleted()
    if @to_be_deleted.any?
      @to_be_deleted.each do |title, rows|
        field_def=CSVMapping.mapping_ui_title_to_relationship[title]
        rows.each do |key, row|
          record = field_def['class'].where(row).first
          if !record.nil?
            @customer.send(field_def['customer_has_many_field']).delete(record)
            @deleted_count+=1
          end
        end
      end
    end
  end


end
