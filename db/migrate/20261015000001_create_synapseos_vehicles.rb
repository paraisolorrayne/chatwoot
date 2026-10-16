class CreateSynapseosVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :synapseos_vehicles do |t|
      t.references :account, null: false, foreign_key: { to_table: :accounts }
      t.string :modelo, null: false
      t.string :versao, null: false, default: ''
      t.integer :ano_modelo
      t.decimal :preco, precision: 12, scale: 2
      t.boolean :disponivel, null: false, default: true
      t.string :categoria
      t.text :descricao
      t.string :imagem_url
      t.string :aliases, array: true, null: false, default: []
      t.jsonb :specs, null: false, default: {}  # demais campos do formato padrão (Synapseos::VehicleSchema)
      t.jsonb :fotos, null: false, default: []  # [{ "label": "Branco - Frontal", "url": "https://..." }]

      t.timestamps
    end

    add_index :synapseos_vehicles, 'account_id, lower(modelo), lower(versao)', unique: true, name: 'idx_synapseos_vehicles_on_account_modelo_versao'
  end
end
