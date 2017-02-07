Sequel.migration do
  change do
    alter_table(:states) do
      add_index :name
      add_index :state
      add_index :start_time
    end
  end
end
