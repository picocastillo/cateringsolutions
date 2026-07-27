class StatusInput < SimpleForm::Inputs::CollectionSelectInput
  def options
    super.reverse_merge label: 'Estado', prompt: false,
                        collection: [['Todos', 'all'], ['Solo activos', 'active'], ['Solo inactivos', 'inactive']]
  end
end
