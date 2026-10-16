# CUSTOMIZAÇÃO_SYNAPSEOS
# Base de conhecimento de veículos. Leitura (lista, ficha e busca do agente)
# para qualquer usuário da conta; editar e importar planilha só administrador.
class Api::V1::Accounts::Synapseos::VehiclesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization, only: [:create, :update, :destroy, :import]
  before_action :fetch_vehicle, only: [:show, :update, :destroy]

  def index
    render json: scope.ordered.map(&:as_api_json)
  end

  def show
    render json: @vehicle.as_api_json
  end

  def schema
    render json: ::Synapseos::VehicleSchema.definition
  end

  def search
    limit = params.fetch(:limit, 5).to_i.clamp(1, 20)
    render json: ::Synapseos::VehicleSearch.new(Current.account, params[:q], limit: limit).call.map(&:as_api_json)
  end

  def create
    vehicle = scope.create!(vehicle_params)
    render json: vehicle.as_api_json
  end

  def update
    @vehicle.update!(vehicle_params)
    render json: @vehicle.as_api_json
  end

  def destroy
    @vehicle.destroy!
    head :ok
  end

  # multipart: file (.xlsx no formato padrão), commit ("true" grava; senão só prévia)
  def import
    importer = ::Synapseos::VehicleSpreadsheetImport.new(Current.account, params.require(:file))
    render json: importer.call(commit: ActiveModel::Type::Boolean.new.cast(params[:commit]))
  rescue ::Synapseos::VehicleSpreadsheetImport::InvalidFile => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def scope
    ::Synapseos::Vehicle.where(account_id: Current.account.id)
  end

  def fetch_vehicle
    @vehicle = scope.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(
      *::Synapseos::VehicleSchema::CORE_FIELDS,
      aliases: [],
      specs: ::Synapseos::VehicleSchema::SPEC_FIELDS,
      fotos: [:label, :url]
    )
  end

  def check_admin_authorization
    render_unauthorized('Acesso restrito a administradores') unless Current.account_user&.administrator?
  end
end
