Sequel.migration do
  change do
    create_table(:customers) do
      uuid :id, primary_key: true, default: Sequel.function(:gen_random_uuid)

      String :full_name, null: false
      Integer :identity_document, null: false
      String :email, null: false
      String :phone

      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
