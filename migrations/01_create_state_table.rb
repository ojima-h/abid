Sequel.migration do
  change do
    create_table(:states) do
      primary_key :id
      String :digest, null: false
      String :name, null: false
      String :params, null: false
      Integer :state
      Time :start_time
      Time :end_time

      index :digest
    end
  end
end
