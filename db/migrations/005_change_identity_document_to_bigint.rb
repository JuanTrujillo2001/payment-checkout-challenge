Sequel.migration do
  change do
    alter_table(:customers) do
      set_column_type :identity_document, :Bignum
    end
  end
end
