::Sequel.migration do
  up do
    create_table(:team_service_pull_states) do
      primary_key :id
      Integer :state, null: false, default: 0
      String :message, size: 250, default: nil
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      foreign_key :team_id, :teams, index: true, null: false
      foreign_key :service_id, :services, index: true, null: false
      unique [:team_id, :service_id]
    end
  end

  down do
    drop_table(:team_service_pull_states)
  end
end
