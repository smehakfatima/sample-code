FactoryGirl.define do

    factory :customer_classification_hierarchy do
        dimension1 ''
        dimension2 ''
        dimension3 ''
        dimension4 ''
        dimension5 ''
        dimension6 ''
        dimension7 ''
        dimension8 ''
        created_by ''
        updated_by ''
        categories_customer_id ''
    end

    factory :category_exclusion do
        categories_customer_id ''
        online_store_assignment_id ''
    end

    factory :brand_alias do
        customer_brand_id ''
        name ''
        created_at ''
        updated_at ''
    end

    factory :customer_drive do
        customer_id ''
        online_store_id ''
        store_number ''
        online_store ''
    end

    factory :geo_upc_black_list do
        customer_id ''
        upc ''
    end

    factory :custom_report do
        customer_id ''
        name ''
        description ''
        site ''
        url ''
        frequency ''
        refresh_responsible ''
        enabled ''
        created_by ''
        updated_by ''
    end

    factory :candidate_brands_filter_type do
        name ''
    end

    factory :country_grouping do
        customer_id ''
        name ''
    end

    factory :competitor_product do
        customer_id ''
        online_store_id ''
        rpc ''
        manufacturer ''
        dimension1 ''
        dimension2 ''
        active ''
        status ''
        lookup_code ''
    end

    factory :manufacturer do
        customer_id ''
        name ''
        is_competitor ''
    end

    factory :dimension do
        customer_id ''
        label ''
        name ''
    end

    factory :dimension_value do
        dimension_id ''
        value ''
        status ''
    end


    factory :report_grouping do
        customer_id ''
        name ''
        color ''
    end

    factory :report_groupings_association do
        report_grouping_id ''
        report_id ''
    end

    factory :customer_milestone do
        name ''
        customer_id ''
        milestone ''
        active ''
    end

    factory :customers_milestones_grouping do
        report_grouping_id ''
        customer_milestone_id ''
    end

    factory :milestone do
        name ''
    end

    factory :online_store do
        name ''
        description ''
        country ''
        page_size ''
        logo_file_name ''
        logo_content_type ''
        logo_updated_at ''
        scrape_code ''
        ocr_extended_traffic_enabled false
    end

    factory :customer_category do
        customer_id ''
        name ''
        description ''
        is_global ''
    end

    factory :customer_media_link do
        customer_id ''
        online_store ''
        country ''
        url ''
    end

    factory :customer do
        name ''
        description ''
        is_global ''
        sku_associated_stores ''
        translations 0
        # initialize_with { Customer.find_or_create_by(name: name)}
    end

    factory :customer_setting_value do
        customer_id nil
        customer_setting_id nil
        value false
        updated_by ''
    end

    factory :report do
        name ''
        description ''
    end

    factory :report_frequency do
        frequency ''
    end

    factory :report_metric do
        report_id ''
        name ''
    end

    factory :customer_alias do
        customer_id ''
        online_store_id ''
        customer_category_id ''
        customer_brand_id ''
        dimension_value_id ''
        add_attribute(:alias) { '' }
    end

    factory :customers_report do
        customer_id ''
        report_id ''
        frequency ''
        day ''
        week1 ''
        week2 ''
        week3 ''
        week4 ''
        date_1 ''
        date_2 ''
    end

    factory :customer_brand do
        customer_id ''
        name ''
        description ''
        manufacturer ''
        is_competitor ''
        is_global ''
        is_media_tracker ''
        image_url ''
    end

    factory :customer_imaging_calculation do
        customer_id ''
        num_type ''
        image_status ''
    end

    factory :customer_threshold do
        customer_id ''
        report_id ''
        report_metric_id ''
        online_store_id ''
        customer_category_id ''
        customer_brand_id ''
        dimension_value_id ''
        success ''
        warning ''
    end

    factory :online_store_assignment do
        customer_id ''
        online_store_id ''
        page_size ''
    end

    factory :reviews_extract_keyword do
        customer_id ''
        keyword ''

    end

    factory :reviews_extract do
        customer_id ''
        next_schedule ''
        paused_schedule ''
    end

    factory :product do
        customer_id ''
        online_store_id ''
        brand_owner ''
        country ''
        rpc ''
        active ''
        url ''
    end

    factory :user do
        email ''
        encrypted_password ''
    end

    factory :search_term do
        customer_id ''
        record_key ''
        search_term ''
        bucket ''
    end

    factory :promotion do
        parent_type ''
        child_type ''
        match_string ''
        formula ''
        region ''
        promotion_price_less_than_online_price ''
        promotion_already_applied ''
        reverse_engineer_list_price ''
        promotion_type ''
    end

    factory :candidate_brands_exclusion do
        customer_id ''
        market ''
        retailer ''
        rpc ''
        product_title ''
    end

    factory :reports_config do
        report_id ''
        name ''
        default_value ''
    end

    factory :customers_reports_config do
        customers_report_id ''
        reports_config_id ''
        value ''
    end

    factory :publish_date do
        customer_id ''
        feed_type_id ''
        publish_date_start ''
    end

    factory :lba_group do
        customer_id ''
        name ''
        created_at ''
        updated_at ''
        description ''
    end

    factory :lba_cluster do
        lba_group_id ''
        customer_id ''
        name ''
        created_at ''
        updated_at ''
    end

    factory :customer_filter_group do
        customer_id ''
        group_type ''
        group_name ''
        is_default_filter ''
        created_at ''
        updated_at ''
    end

    factory :customer_filter_group_value do
        customer_filter_group_id ''
        linked_filter_value_id ''
        created_at ''
        updated_at ''
    end

    factory :customer_search_term do
        customer_id ''
        search_term ''
        priority false
        created_at DateTime.now
        removed_at nil
    end

    factory :customer_search_term_online_store do
        customer_search_term_id ''
        online_store_id ''
        created_at DateTime.now
        removed_at nil
    end

    factory :customer_search_term_segment do
        customer_search_term_id ''
        segment ''
        priority false
        created_at DateTime.now
        removed_at nil
    end

    factory :secondary_image_type do
        customer_id ''
        type_name ''
        type_short_name ''
        type_code ''
        type_regex_pattern ''
        display_name ''
    end

    factory :shared_report do
        customer_id ''
        name ''
        description ''
        dashboard_id ''
        emails ''
        is_enabled ''
        created_by ''
        updated_by ''
    end
    factory :customer_setting do
        setting_name ''
        setting_desc ''
        default_value false
    end

    factory :scheduled_export do
        customer_id ''
        name 'test name'
        ui_filters Hash.new
        date_range 0
        created_by 'test@test.com'
        payload Hash.new
        report_name 'test report name'
        report_settings Hash.new
        is_deleted false
        is_enabled true
        created_at DateTime.now
        updated_at DateTime.now
    end

    factory :customer_search_term_group do
        customer_id ''
        group_name ''
        customer_milestone ''
    end

    factory :customer_search_term_group_association do
        customer_search_term_id ''
        customer_search_term_group_id ''
        created_at ''
    end

    factory :customer_dashboard_tile_order do
        tile_type ''
        customers_reports_id ''
        milestone_id ''
        position ''
        weighting ''
    end

    factory :sso_meta_connection, class: Sso::MetaConnection do
        updated_by 'Joe Bloggs'
    end

    factory :audit do
        auditable_id ''
        auditable_type ''
        associated_id ''
        associated_type ''
        user_id ''
        user_type ''
        username ''
        action ''
        audited_changes ''
        version ''
        comment ''
        remote_address ''
        request_uuid ''
        created_at Time.now
    end
end
