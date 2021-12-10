class CSVPreviewer
  include ActiveModel::Validations
  extend ActiveModel::Naming

  attr_reader :errors, :to_be_added, :to_be_deleted, :added_count, :deleted_count

  def initialize(customer,file, delete_from_db_if_not_in_the_csv)
    @customer = customer
    @file=file
    @delete_from_db_if_not_in_the_csv=delete_from_db_if_not_in_the_csv

    @errors = ActiveModel::Errors.new(self)
    @to_be_added ={}
    @to_be_deleted ={}
  end

  def preview()
    build_preview if valid_header_row?
  end


  private

  def valid_header_row?
    is_valid, error_message = CSVValidator.validate_exact_header_row(@file, CSVMapping.valid_column_names)
    @errors.add(:base, error_message) if !is_valid
    is_valid
  end

  def build_preview()
    rows_from_csv = CSVValidator.read_csv_and_normalize_as_rows(@file)
    CSVMapping.mapping_csv_header_to_relationship.each do |header, field_def|
      diff_csv_with_db_for_single_field(rows_from_csv, field_def)
    end
    if !@to_be_deleted.any? && !@to_be_added.any?
      @errors.add(:base, 'CSV file and db is in sync, nothing to add or delete!')
    end
  end

  def diff_csv_with_db_for_single_field(data_from_csv, field_def)
    csv_records_for_field=parse_valid_rows_for_single_field(data_from_csv, field_def)
    @customer.send(field_def['customer_has_many_field']).each do |record|
      mark_record_to_be_added_or_deleted(csv_records_for_field, field_def, record)
    end
    
    @to_be_added[field_def['title']]=csv_records_for_field if csv_records_for_field.any?
  end

  def mark_record_to_be_added_or_deleted(csv_records_for_field, field_def, record)
    record_key=''
    record_with_required_fields={}
    field_def['to_fields'].each do |field_name|
        if !record[field_name].nil?
        record_key=record_key+','+record[field_name]
        record_with_required_fields[field_name]=record[field_name]
        end
  
    end
  
    if csv_records_for_field.include?(record_key)
      csv_records_for_field.delete(record_key)
    else
      if @delete_from_db_if_not_in_the_csv
        @to_be_deleted[field_def['title']] ||= {}
        @to_be_deleted[field_def['title']][record_key] = record_with_required_fields
      end
    end
  end


  def parse_valid_rows_for_single_field(data_from_csv, field_def)
    key_to_model_mapping={}
    data_from_csv.each_with_index do |row, row_index|
      key=''
      model={}
      field_def['from_columns'].each_with_index do |column_name, column_index|
        if row[column_name]
          key=key+','+row[column_name]
          model[field_def['to_fields'][column_index]]=row[column_name]
        else
          if !model['name'].nil? && column_name=='country'
            @errors.add(:base, "required column #{column_name} is empty at row #{row_index+1}")
          end
        end
      end
      key_to_model_mapping[key]=model if model.any?
    end
    key_to_model_mapping
  end

end