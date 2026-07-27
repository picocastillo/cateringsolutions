class Ability
  include CanCan::Ability

  attr_reader :user

  def initialize(user)
    @user = user

    alias_action :read, :create, :update, to: :change
    alias_action :update, :destroy, to: :modify
    alias_action :pdf_index, :xls_index, to: :export_index
    alias_action :pdf_show, :xls_show, :csv_show, to: :export_show
    alias_action :export_index, :export_show, to: :export
    alias_action :read, :export, :import, to: :masive_change

    Dir['app/models/**/authorization.rb'].each do |dir|
      auth_module = dir[%r{app/models/(.*)\.rb}, 1].camelize.constantize
      auth_module.new(self).add_rules
    end
  end

  class Subrules
    delegate :can, :cannot, :can?, :user, to: :@ability
    delegate :admin?, :cliente?, :accede_a_modulo?, to: :user

    def initialize(ability)
      @ability = ability
    end

    def roles? *role_names
      user.cumple_algun_rol?(*role_names)
    end
    alias rol? roles?
  end
end
