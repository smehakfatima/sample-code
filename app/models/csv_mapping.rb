class CSVMapping

  def self.valid_column_names
    ['retailer', 'country']
  end

  def self.mapping_csv_header_to_relationship
    {
      'retailer' => {
        'class' => OnlineStore,
        'customer_has_many_field' => 'online_stores',
        'from_columns' => ['retailer', 'country'],
        'to_fields' => ['name', 'country'],
        'title' => 'Online Stores',
      },

    }
  end

  def self.mapping_ui_title_to_relationship
    ui_fields={}
    mapping_csv_header_to_relationship.each do |header, field_def|
      ui_fields[field_def['title']]=field_def
    end
    ui_fields
  end

end
