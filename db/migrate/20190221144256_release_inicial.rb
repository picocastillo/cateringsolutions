class ReleaseInicial < ActiveRecord::Migration[5.2]
  def change
    if Rails.env.development?
      create_table "afectaciones", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "comprobante_id"
        t.integer "afectado_id"
        t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["afectado_id"], name: "index_afectaciones_on_afectado_id"
        t.index ["comprobante_id"], name: "index_afectaciones_on_comprobante_id"
        t.index ["created_at"], name: "index_afectaciones_on_created_at"
      end

      create_table "audits", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "auditable_id"
        t.string "auditable_type"
        t.integer "associated_id"
        t.string "associated_type"
        t.integer "user_id"
        t.string "user_type"
        t.string "username"
        t.string "action"
        t.text "audited_changes"
        t.integer "version", default: 0
        t.string "comment"
        t.string "remote_address"
        t.string "request_uuid"
        t.datetime "created_at"
        t.index ["associated_type", "associated_id"], name: "associated_index"
        t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
        t.index ["created_at"], name: "index_audits_on_created_at"
        t.index ["request_uuid"], name: "index_audits_on_request_uuid"
        t.index ["user_id", "user_type"], name: "user_index"
      end

      create_table "categorias", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.integer "codigo"
        t.string "descripcion"
        t.boolean "menu_diario", default: false, null: false
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.integer "tienda_id"
        t.index ["codigo"], name: "index_categorias_on_codigo"
        t.index ["discontinued_at"], name: "index_categorias_on_discontinued_at"
        t.index ["nombre"], name: "index_categorias_on_nombre"
        t.index ["tienda_id"], name: "index_categorias_on_tienda_id"
      end

      create_table "clientes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.string "cuit"
        t.string "ciudad"
        t.string "domicilio"
        t.string "email"
        t.string "nro_inscripcion_iibb", limit: 15
        t.string "telefono"
        t.integer "dia_inicio_ciclo_facturacion", default: 1, null: false
        t.integer "vencimiento_a", default: 15, null: false
        t.string "horario_corte_pedidos", default: "00:00", null: false
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.boolean "permitir_envios_a_domicilio", default: false
        t.integer "tienda_id"
        t.boolean "codigo_externo_en_etiquetas", default: false
        t.boolean "usuario_puede_elegir_cuenta", default: false, null: false
        t.boolean "mostrar_cuentas_corrientes", default: false, null: false
        t.boolean "pago_ml", default: false
        t.index ["cuit"], name: "index_clientes_on_cuit"
        t.index ["discontinued_at"], name: "index_clientes_on_discontinued_at"
        t.index ["tienda_id"], name: "index_clientes_on_tienda_id"
      end

      create_table "clientes_categorias", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "cliente_id"
        t.integer "categoria_id"
        t.index ["categoria_id"], name: "index_clientes_categorias_on_categoria_id"
        t.index ["cliente_id"], name: "index_clientes_categorias_on_cliente_id"
      end

      create_table "clientes_precios", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "cliente_id"
        t.integer "precio_id"
        t.index ["cliente_id"], name: "index_clientes_precios_on_cliente_id"
        t.index ["precio_id"], name: "index_clientes_precios_on_precio_id"
      end

      create_table "comprobantes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "type"
        t.bigint "tipo_id"
        t.bigint "pedido_id"
        t.bigint "cuenta_id"
        t.integer "estado_id", default: 1
        t.datetime "fecha_emision"
        t.date "fecha_vencimiento"
        t.integer "nro"
        t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
        t.datetime "created_at"
        t.datetime "updated_at"
        t.integer "position"
        t.integer "generado_por_id"
        t.bigint "autor_id"
        t.datetime "contabilizado_el"
        t.string "descripcion"
        t.integer "evento_id"
        t.boolean "automatico", default: false, null: false
        t.integer "bonificacion", default: 0, null: false
        t.integer "historial_id"
        t.integer "tienda_id"
        t.index ["autor_id"], name: "index_comprobantes_on_autor_id"
        t.index ["contabilizado_el"], name: "index_comprobantes_on_contabilizado_el"
        t.index ["cuenta_id"], name: "index_comprobantes_on_cuenta_id"
        t.index ["descripcion"], name: "index_comprobantes_on_descripcion"
        t.index ["estado_id"], name: "index_comprobantes_on_estado_id"
        t.index ["evento_id"], name: "index_comprobantes_on_evento_id"
        t.index ["fecha_emision"], name: "index_comprobantes_on_fecha_emision"
        t.index ["generado_por_id"], name: "index_comprobantes_on_generado_por_id"
        t.index ["historial_id"], name: "index_comprobantes_on_historial_id"
        t.index ["nro"], name: "index_comprobantes_on_nro"
        t.index ["pedido_id"], name: "index_comprobantes_on_pedido_id"
        t.index ["tienda_id", "tipo_id", "nro"], name: "index_comp_on_tienda_id_tc_nro", unique: true
        t.index ["tienda_id"], name: "index_comprobantes_on_tienda_id"
        t.index ["tipo_id", "nro"], name: "index_comprobantes_on_tc_nro"
        t.index ["tipo_id"], name: "index_comprobantes_on_tipo_id"
        t.index ["type"], name: "index_comprobantes_on_type"
        t.index ["updated_at"], name: "index_comprobantes_on_updated_at"
      end

      create_table "comprobantes_asociados", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "comprobante_id"
        t.integer "asociado_id"
        t.index ["asociado_id"], name: "index_comprobantes_asociados_on_asociado_id"
        t.index ["comprobante_id"], name: "index_comprobantes_asociados_on_comprobante_id"
      end

      create_table "configuraciones_impositivas", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "type"
        t.integer "cliente_id"
        t.integer "impuesto_id"
        t.integer "condicion_id"
        t.index ["cliente_id"], name: "index_configuraciones_impositivas_on_cliente_id"
        t.index ["condicion_id"], name: "index_configuraciones_impositivas_on_condicion_id"
        t.index ["impuesto_id"], name: "index_configuraciones_impositivas_on_impuesto_id"
        t.index ["type"], name: "index_configuraciones_impositivas_on_type"
      end

      create_table "cuentas", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "nro"
        t.string "nombre"
        t.integer "position"
        t.bigint "cliente_id"
        t.datetime "discontinued_at"
        t.datetime "created_at"
        t.datetime "updated_at"
        t.index ["cliente_id"], name: "index_cuentas_on_cliente_id"
        t.index ["nombre"], name: "index_cuentas_clientes_on_nombre"
        t.index ["position"], name: "index_cuentas_clientes_on_position"
      end

      create_table "delayed_jobs", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "priority", default: 0, null: false
        t.integer "attempts", default: 0, null: false
        t.text "handler", null: false
        t.text "last_error"
        t.datetime "run_at"
        t.datetime "locked_at"
        t.datetime "failed_at"
        t.string "locked_by"
        t.string "queue"
        t.datetime "created_at"
        t.datetime "updated_at"
        t.index ["priority", "run_at"], name: "delayed_jobs_priority"
      end

      create_table "documentos", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "documentable_id"
        t.string "documentable_type"
        t.string "documento_file_name"
        t.string "documento_content_type"
        t.integer "documento_file_size"
        t.datetime "documento_updated_at"
        t.integer "position"
        t.integer "autor_id"
        t.string "observaciones"
        t.index ["autor_id"], name: "index_imagenes_on_autor_id"
        t.index ["documentable_id", "documentable_type"], name: "index_documentos_on_documentable_id_and_documentable_type"
        t.index ["documentable_type"], name: "index_documentos_on_migrado_and_imagen_id_and_documentable_type"
        t.index ["position"], name: "index_documentos_on_position"
      end

      create_table "etiquetas_notificables", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "etiquetado_id"
        t.string "etiquetado_type"
        t.integer "etiquetador_id"
        t.string "etiquetador_type"
        t.string "nombre"
        t.index ["etiquetado_id", "etiquetado_type"], name: "index_etiquetas_notificables_on_etiquetado"
        t.index ["etiquetado_type"], name: "index_etiquetas_notificables_on_etiquetado_type"
        t.index ["etiquetador_id", "etiquetador_type"], name: "index_etiquetas_notificables_on_etiquetable"
        t.index ["etiquetador_type"], name: "index_etiquetas_notificables_on_etiquetador_type"
      end

      create_table "eventos", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "type"
        t.integer "usuario_id"
        t.string "origen_type"
        t.integer "origen_id"
        t.datetime "fecha", null: false
        t.integer "position"
        t.integer "estado_generado_id"
        t.text "mensajes"
        t.string "interface"
        t.string "nro_lote"
        t.string "codigo_sobre_proveedor"
        t.boolean "exitoso", default: false, null: false
        t.integer "historial_id"
        t.index ["estado_generado_id"], name: "index_eventos_on_estado_generado_id"
        t.index ["fecha"], name: "index_eventos_on_fecha"
        t.index ["historial_id"], name: "index_eventos_on_historial_id"
        t.index ["origen_type", "origen_id"], name: "index_eventos_on_origen_type_and_origen_id"
        t.index ["position"], name: "index_eventos_on_position"
        t.index ["type"], name: "index_eventos_on_type"
        t.index ["usuario_id"], name: "index_eventos_on_usuario_id"
      end

      create_table "favoritos", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "usuario_id"
        t.bigint "producto_id"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["producto_id"], name: "index_favoritos_on_producto_id"
        t.index ["usuario_id", "producto_id", "updated_at"], name: "index_favoritos_on_usuario_id_and_producto_id_and_updated_at"
        t.index ["usuario_id"], name: "index_favoritos_on_usuario_id"
      end

      create_table "feriados", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "calendario_id"
        t.date "fecha"
        t.string "descripcion"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["calendario_id"], name: "index_feriados_on_calendario_id"
        t.index ["fecha"], name: "index_feriados_on_fecha"
      end

      create_table "generadores_secuenciales", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "scope", limit: 50
        t.string "type", limit: 50
        t.integer "ultimo", default: 0, null: false
        t.index ["scope", "ultimo"], name: "index_generadores_secuenciales_unique", unique: true
      end

      create_table "grupos", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.string "nombre"
        t.string "descripcion"
        t.datetime "discontinued_at"
        t.index ["discontinued_at"], name: "index_grupos_on_discontinued_at"
      end

      create_table "historiales", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
      end

      create_table "imagenes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "imaginable_id"
        t.string "imaginable_type"
        t.string "imagen_file_name"
        t.string "imagen_content_type"
        t.integer "imagen_file_size"
        t.datetime "imagen_updated_at"
        t.integer "position"
        t.string "pie"
      end

      create_table "medios_pago", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "type"
        t.integer "flujo_economico_id"
        t.boolean "propio", default: true, null: false
        t.integer "tipo_id"
        t.integer "nro"
        t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
        t.integer "cuenta_id"
        t.integer "sucursal"
        t.integer "cp"
        t.date "fecha_emision"
        t.date "fecha_presentacion"
        t.date "fecha_acreditacion"
        t.string "cuit"
        t.datetime "created_at"
        t.datetime "updated_at"
        t.integer "cuenta_bancaria_id"
        t.date "fecha_retencion"
        t.index ["cuenta_bancaria_id"], name: "index_medios_pago_on_cuenta_bancaria_id"
        t.index ["cuenta_id"], name: "index_medios_pago_on_cuenta_id"
        t.index ["fecha_acreditacion"], name: "index_medios_pago_on_fecha_acreditacion"
        t.index ["fecha_emision"], name: "index_medios_pago_on_fecha_emision"
        t.index ["fecha_presentacion"], name: "index_medios_pago_on_fecha_presentacion"
        t.index ["flujo_economico_id"], name: "index_medios_pago_on_flujo_economico_id"
        t.index ["nro"], name: "index_medios_pago_on_nro"
        t.index ["type"], name: "index_medios_pago_on_type"
      end

      create_table "mensajes", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "autor_id"
        t.string "asunto"
        t.boolean "admite_comentarios", default: true
        t.text "cuerpo"
        t.datetime "created_at"
        t.datetime "updated_at"
        t.datetime "recordar_el"
        t.string "recordar_a", default: "a_mi"
        t.integer "duracion", default: 2
        t.integer "mensaje_id"
        t.integer "respuesta_de_id"
        t.boolean "mostrar_destinatarios", default: true, null: false
        t.integer "version_logica", default: 3, null: false
        t.index ["asunto", "cuerpo"], name: "full", type: :fulltext
        t.index ["asunto"], name: "index_mensajes_on_asunto"
        t.index ["autor_id"], name: "index_mensajes_on_autor_id"
        t.index ["created_at", "mensaje_id"], name: "index_mensajes_on_created_at_mensaje_id"
        t.index ["mensaje_id"], name: "index_mensajes_on_mensaje_id"
        t.index ["respuesta_de_id"], name: "index_mensajes_on_respuesta_de_id"
        t.index ["updated_at"], name: "index_mensajes_on_updated_at"
      end

      create_table "menus_diarios", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "producto_id"
        t.bigint "autor_id"
        t.date "fecha"
        t.string "descripcion"
        t.integer "position"
        t.text "observaciones"
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.integer "tienda_id"
        t.index ["autor_id"], name: "index_menus_diarios_on_autor_id"
        t.index ["discontinued_at"], name: "index_horarios_laborales_on_discontinued_at"
        t.index ["producto_id", "position"], name: "index_horarios_laborales_on_position"
        t.index ["producto_id"], name: "index_menus_diarios_on_producto_id"
        t.index ["tienda_id"], name: "index_menus_diarios_on_tienda_id"
      end

      create_table "movimientos_cbles", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "cuenta_id"
        t.integer "comprobante_id"
        t.integer "imputado_id"
        t.integer "afectacion_id"
        t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
        t.decimal "saldo", precision: 12, scale: 2, default: "0.0", null: false
        t.datetime "created_at"
        t.integer "indice"
        t.integer "tienda_id"
        t.index ["afectacion_id"], name: "index_movimientos_on_afectacion_id"
        t.index ["comprobante_id"], name: "index_movimientos_on_comprobante_id"
        t.index ["cuenta_id"], name: "index_movimientos_on_cuenta_id"
        t.index ["imputado_id"], name: "index_movimientos_on_imputado_id"
        t.index ["indice"], name: "index_movimientos_cbles_on_indice"
        t.index ["saldo"], name: "index_movimientos_cbles_on_saldo"
        t.index ["tienda_id"], name: "index_movimientos_cbles_on_tienda_id"
      end

      create_table "notificaciones", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.string "type"
        t.datetime "created_at"
        t.datetime "updated_at"
      end

      create_table "notificaciones_enviadas", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "notificacion_id"
        t.integer "destinatario_id"
        t.integer "remitente_id"
        t.integer "via_id", default: 1, null: false
        t.integer "mensaje_id"
        t.datetime "leida_el"
        t.boolean "favorita", default: false, null: false
        t.datetime "created_at"
        t.datetime "updated_at"
        t.boolean "ultima", default: false, null: false
        t.integer "sin_leer_en_cadena", default: 0, null: false
        t.index ["destinatario_id", "mensaje_id", "via_id"], name: "index_notificaciones_enviadas_mensaje_favorito"
        t.index ["destinatario_id", "via_id", "favorita"], name: "index_notificaciones_enviadas_query_panel_favoritos"
        t.index ["destinatario_id", "via_id", "leida_el"], name: "index_notificaciones_enviadas_query_panel_no_leidos"
        t.index ["destinatario_id", "via_id", "ultima", "created_at"], name: "index_notificaciones_enviadas_query_panel_main"
        t.index ["mensaje_id"], name: "index_notificaciones_enviadas_on_mensaje_id"
        t.index ["notificacion_id", "destinatario_id", "via_id"], name: "index_notificaciones_enviadas_unique", unique: true
        t.index ["remitente_id"], name: "index_notificaciones_enviadas_on_remitente_id"
      end

      create_table "pedidos", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "autor_id"
        t.bigint "usuario_id"
        t.date "fecha"
        t.integer "codigo"
        t.string "viendo_categorias_csv"
        t.string "busqueda"
        t.integer "estado_id", default: 1
        t.string "observaciones_cliente"
        t.string "observaciones_chef"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.boolean "envio_a_domicilio", default: false
        t.string "direccion_envio"
        t.string "confirmation_token", limit: 26, index: true
        t.integer "tienda_id"
        t.boolean "venta_mostrador", default: false
        t.integer "cuenta_id"
        t.boolean "pedido_para_empresa", default: false
        t.string "para"
        t.boolean "facturado", default: false
        t.index ["autor_id"], name: "index_pedidos_on_autor_id"
        t.index ["cuenta_id"], name: "index_pedidos_on_cuenta_id"
        t.index ["estado_id"], name: "index_pedidos_on_estado_id"
        t.index ["fecha", "codigo"], name: "index_pedidos_on_fecha_and_codigo"
        t.index ["fecha"], name: "index_pedidos_fecha"
        t.index ["tienda_id"], name: "index_pedidos_on_tienda_id"
        t.index ["usuario_id", "fecha", "codigo"], name: "index_pedidos_on_usuario_id_fecha_and_codigo"
        t.index ["usuario_id"], name: "index_pedidos_on_usuario_id"
      end

      create_table "pedidos_productos_solicitados", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "pedido_id"
        t.integer "producto_solicitado_id"
        t.index ["pedido_id", "producto_solicitado_id"], name: "i_trat_tur_on_pedido_id_and_producto_solicitado_id"
      end

      create_table "plantillas", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.string "clase_cbte"
        t.index ["clase_cbte"], name: "index_plantillas_on_clase_cbte"
      end

      create_table "precios", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "producto_id"
        t.date "fecha_desde"
        t.date "fecha_hasta"
        t.integer "position"
        t.decimal "importe", precision: 12, scale: 2, default: "0.0", null: false
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["discontinued_at"], name: "index_horarios_laborales_on_discontinued_at"
        t.index ["producto_id", "position"], name: "precios_on_position"
        t.index ["producto_id"], name: "index_precios_on_producto_id"
      end

      create_table "preferencias", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.boolean "estado", default: false
        t.string "valor"
        t.bigint "usuario_id"
        t.index ["usuario_id", "nombre"], name: "index_preferencias_on_usuario_id_and_nombre", unique: true
        t.index ["usuario_id"], name: "index_preferencias_on_usuario_id"
      end

      create_table "procesos", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.string "type"
        t.date "desde"
        t.date "hasta"
        t.text "params"
        t.datetime "run_at"
        t.integer "autor_id"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.string "adjunto_file_name"
        t.string "adjunto_content_type"
        t.string "adjunto_file_size"
        t.boolean "importar", default: false, null: false
        t.integer "generado_por_id"
        t.integer "tienda_id"
        t.index ["autor_id"], name: "index_procesos_on_autor_id"
        t.index ["tienda_id", "autor_id"], name: "index_procesos_on_tienda_id_autor_id"
      end

      create_table "productos", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "categoria_id"
        t.string "nombre"
        t.string "codigo"
        t.string "descripcion"
        t.string "color"
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.integer "tienda_id"
        t.string "codigos_externos"
        t.index ["categoria_id", "nombre"], name: "index_productos_on_categoria_id_and_nombre"
        t.index ["categoria_id"], name: "index_productos_on_categoria_id"
        t.index ["codigo"], name: "index_productos_on_nombre"
        t.index ["discontinued_at"], name: "index_productos_on_discontinued_at"
        t.index ["nombre"], name: "index_productos_on_codigo"
        t.index ["tienda_id"], name: "index_productos_on_tienda_id"
      end

      create_table "productos_solicitados", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "pedido_id"
        t.bigint "producto_id"
        t.integer "cantidad", default: 0, null: false
        t.decimal "precio_unitario", precision: 12, scale: 2, default: "0.0", null: false
        t.text "observaciones_cliente"
        t.text "observaciones_chef"
        t.boolean "realizado", default: false, null: false
        t.boolean "pesable", default: false
        t.integer "menu_diario_id"
        t.index ["menu_diario_id"], name: "index_productos_solicitados_on_menu_diario_id"
        t.index ["pedido_id"], name: "index_productos_solicitados_on_pedido_id"
        t.index ["producto_id"], name: "index_productos_solicitados_on_producto_id"
      end

      create_table "progresos", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "progresable_id"
        t.string "progresable_type"
        t.integer "actual", default: 0, null: false
        t.integer "total", default: 0, null: false
        t.datetime "fecha_inicio"
        t.datetime "fecha_fin"
        t.text "errores"
        t.boolean "cancelado", default: false, null: false
      end

      create_table "provincias", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "codigo"
        t.string "nombre", limit: 20
        t.string "letra", limit: 1
      end

      create_table "recordatorios", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "mensaje_id"
        t.integer "destinatario_id"
        t.integer "autor_id"
        t.datetime "created_at"
        t.datetime "recordar_el"
        t.integer "duracion", default: 2, null: false
        t.index ["recordar_el"], name: "index_recordatorios_on_recordar_el"
      end

      create_table "renglones", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.bigint "comprobante_id"
        t.integer "tasa_iva_id", default: 1, null: false
        t.bigint "producto_id"
        t.string "descripcion", limit: 500
        t.integer "cantidad", default: 1, null: false
        t.decimal "precio_unitario", precision: 12, scale: 2, default: "0.0", null: false
        t.bigint "comprobante_afectado_id"
        t.bigint "categoria_id"
        t.index ["categoria_id"], name: "index_renglones_on_categoria_id"
        t.index ["comprobante_afectado_id"], name: "index_renglones_on_comprobante_afectado_id"
        t.index ["comprobante_id"], name: "index_renglones_on_comprobante_id"
        t.index ["producto_id"], name: "index_renglones_on_producto_id"
      end

      create_table "roles", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.string "titulo"
        t.string "modulo"
        t.boolean "sugerido", default: false, null: false
        t.text "transitivos"
        t.text "descripcion"
        t.index ["modulo"], name: "index_roles_on_modulo"
      end

      create_table "roles_asignados", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "usuario_id", null: false
        t.integer "rol_id", null: false
        t.index ["usuario_id", "rol_id"], name: "index_roles_asignados_on_usuario_id_and_rol_id", unique: true
      end

      create_table "sessions", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "session_id", null: false
        t.text "data"
        t.integer "user_id"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
        t.index ["updated_at"], name: "index_sessions_on_updated_at"
        t.index ["user_id"], name: "index_sessions_on_user_id"
      end

      create_table "subtotales", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "comprobante_id"
        t.integer "tasa_iva_id"
        t.decimal "base_imponible", precision: 12, scale: 2, default: "0.0", null: false
        t.decimal "iva", precision: 12, scale: 2, default: "0.0", null: false
        t.index ["comprobante_id", "tasa_iva_id"], name: "index_subtotales_on_comprobante_id_and_tasa_iva_id", unique: true
        t.index ["comprobante_id"], name: "index_subtotales_on_comprobante_id"
      end

      create_table "suscripciones", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "usuario_id"
        t.integer "tipo_id"
        t.string "vias_ids"
        t.index ["tipo_id"], name: "index_suscripciones_on_tipo_id"
        t.index ["usuario_id", "tipo_id"], name: "index_suscripciones_on_usuario_id_and_tipo_id", unique: true
      end

      create_table "taggings", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.integer "tag_id"
        t.integer "taggable_id"
        t.integer "tagger_id"
        t.string "tagger_type"
        t.string "taggable_type"
        t.string "context"
        t.datetime "created_at"
        t.index ["tag_id"], name: "index_taggings_on_tag_id"
        t.index ["taggable_id", "taggable_type", "context"], name: "index_taggings_on_taggable_id_and_taggable_type_and_context"
      end

      create_table "tags", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
        t.string "name"
        t.text "description"
        t.integer "taggings_count", default: 0
      end

      create_table "tiendas", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "nombre"
        t.string "descripcion"
        t.string "color_de_fondo"
        t.string "color_de_menu"
        t.string "color_barra_superior"
        t.string "color_fondo_logo"
        t.string "color_barra_filtros"
        t.string "color_links_hover"
        t.string "color_links"
        t.string "color_titulo"
        t.string "dominio"
        t.string "email"
        t.string "telefono"
        t.string "domicilio"
        t.string "video_ayuda"
        t.text "mensaje_bienvenida"
        t.string "mensaje_ingreso_a_carrito"
        t.datetime "discontinued_at"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
        t.boolean "venta_mostrador", default: false
        t.boolean "carrito_de_compras", default: false
        t.boolean "despachos", default: false
        t.index ["discontinued_at"], name: "index_tiendas_on_discontinued_at"
        t.index ["dominio"], name: "index_tiendas_on_dominio"
      end

      create_table "tipos_comprobantes", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "desc"
        t.string "clase", limit: 50
        t.string "letra", limit: 1
        t.integer "codigo"
        t.boolean "debitan", default: true, null: false
        t.index ["codigo"], name: "index_tipos_comprobantes_on_codigo"
        t.index ["letra", "clase"], name: "index_tipos_comprobantes_on_letra_and_clase"
      end

      create_table "usuarios", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.string "login"
        t.string "crypted_password", limit: 40
        t.string "salt", limit: 40
        t.datetime "created_at"
        t.bigint "cuenta_id"
        t.datetime "updated_at"
        t.string "remember_token"
        t.datetime "remember_token_expires_at"
        t.string "nombre"
        t.string "telefono"
        t.string "email"
        t.datetime "password_expires_at", default: "2036-01-01 00:00:00"
        t.integer "notificaciones_sin_leer", default: 0, null: false
        t.boolean "recordatorios_activos", default: false, null: false
        t.boolean "alertar_notificaciones", default: false, null: false
        t.datetime "discontinued_at"
        t.integer "dni"
        t.string "cuit"
        t.string "legajo"
        t.string "direccion_envio"
        t.integer "tipo_usuario_id"
        t.integer "tienda_cliente_id"
        t.integer "visualizando_tienda_id"
        t.string "sucursal"
        t.index ["cuenta_id", "dni"], name: "index_usuarios_on_cuenta_id_and_dni"
        t.index ["cuenta_id", "legajo"], name: "index_usuarios_on_cuenta_id_and_legajo"
        t.index ["cuenta_id", "login"], name: "index_usuarios_on_cuenta_id_and_login"
        t.index ["cuenta_id", "nombre"], name: "index_usuarios_on_cuenta_id_and_nombre"
        t.index ["cuenta_id"], name: "index_usuarios_on_cuenta_id"
        t.index ["cuit"], name: "index_usuarios_on_cuit"
        t.index ["discontinued_at"], name: "index_usuarios_on_discontinued_at"
        t.index ["dni"], name: "index_usuarios_on_dni"
        t.index ["legajo"], name: "index_usuarios_on_legajo"
        t.index ["login"], name: "index_usuarios_on_login"
        t.index ["tienda_cliente_id"], name: "index_usuarios_on_tienda_cliente_id"
        t.index ["visualizando_tienda_id"], name: "index_usuarios_on_visualizando_tienda_id"
      end

      create_table "usuarios_tiendas", id: false, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci", force: :cascade do |t|
        t.integer "usuario_id"
        t.integer "tienda_id"
        t.index ["tienda_id"], name: "index_usuarios_tiendas_on_tienda_id"
        t.index ["usuario_id"], name: "index_usuarios_tiendas_on_usuario_id"
      end

      [
        { codigo: 901, letra: 'C', nombre: 'CABA' },
        { codigo: 902, letra: 'B', nombre: 'Buenos Aires' },
        { codigo: 903, letra: 'K', nombre: 'Catamarca' },
        { codigo: 904, letra: 'X', nombre: 'Córdoba' },
        { codigo: 905, letra: 'W', nombre: 'Corrientes' },
        { codigo: 906, letra: 'H', nombre: 'Chaco' },
        { codigo: 907, letra: 'U', nombre: 'Chubut' },
        { codigo: 908, letra: 'E', nombre: 'Entre Ríos' },
        { codigo: 909, letra: 'P', nombre: 'Formosa' },
        { codigo: 910, letra: 'Y', nombre: 'Jujuy' },
        { codigo: 911, letra: 'L', nombre: 'La Pampa' },
        { codigo: 912, letra: 'F', nombre: 'La Rioja' },
        { codigo: 913, letra: 'M', nombre: 'Mendoza' },
        { codigo: 914, letra: 'N', nombre: 'Misiones' },
        { codigo: 915, letra: 'Q', nombre: 'Neuquén' },
        { codigo: 916, letra: 'R', nombre: 'Río Negro' },
        { codigo: 917, letra: 'A', nombre: 'Salta' },
        { codigo: 918, letra: 'J', nombre: 'San Juan' },
        { codigo: 919, letra: 'D', nombre: 'San Luis' },
        { codigo: 920, letra: 'Z', nombre: 'Santa Cruz' },
        { codigo: 921, letra: 'S', nombre: 'Santa Fe' },
        { codigo: 922, letra: 'G', nombre: 'Santiago del Estero' },
        { codigo: 923, letra: 'V', nombre: 'Tierra del Fuego' },
        { codigo: 924, letra: 'T', nombre: 'Tucumán' }
      ].each { |attrs| Referencia::Provincia.create_or_update_by :codigo, attrs }

      [
      { modulo: 'Usuarios', nombre: 'admin', titulo: 'Administrador' },
      { modulo: 'Usuarios', nombre: 'gestiona_usuarios', titulo: 'Gestiona usuarios' },
      { modulo: 'Usuarios', nombre: 'robot', titulo: 'Robot', descripcion: 'Reservado para uso interno del sistema' },
      { modulo: 'Usuarios', nombre: 'comprador', titulo: 'Comprador', descripcion: 'Usuarios compradores de la empresa cliente seleccionada en el tab General' },
      { modulo: 'Usuarios', nombre: 'administrador_empresa', titulo: 'Administrador de Empresa Cliente', descripcion: 'Usuarios administradores de la empresa cliente seleccionada en el tab General' },
      { modulo: 'Clientes', nombre: 'gestiona_clientes', titulo: 'Gestiona Clientes' },
      { modulo: 'Pedidos', nombre: 'gestiona_pedidos', titulo: 'Gestiona Pedidos' },
      { modulo: 'Productos', nombre: 'gestiona_productos', titulo: 'Gestiona Productos' },
      { modulo: 'Administración', nombre: 'gestiona_comprobantes', titulo: 'Gestiona Comprobantes' },
      { modulo: 'Administración', nombre: 'gestiona_movimientos', titulo: 'Gestiona Cuentas Corrientes y Saldos' },
      { modulo: 'Productos', nombre: 'gestiona_menus_diarios', titulo: 'Gestiona Menús Diarios' },
      { modulo: 'Contenido', nombre: 'gestiona_contenidos_web', titulo: 'Gestiona Contenidos portal público' }
    ].each { |attrs| Usuarios::Rol.create_or_update_by :nombre, attrs }

      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 1, desc: "Remito", clase: 'Ventas::Facturacion::Factura'
      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 2, desc: "Nota de Débito C", letra: 'C', clase: 'Ventas::Facturacion::NotaDebito'
      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 3, desc: "Nota de Crédito C", letra: 'C', clase: 'Ventas::Facturacion::NotaCredito', debitan: false
      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 4, desc: "Recibo X", letra: 'X', clase: 'Cobros::Recibo'
      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 5, desc: "Orden de Pago O", letra: 'C', clase: 'Facturacion::OrdenPago', debitan: false
      Comprobantes::Tipo.create_or_update_by :codigo, codigo: 6, desc: "Pago P", letra: 'E', clase: 'Entregas::Pago', debitan: false

        heavy = Productos::Producto.where(id: 1).first
        sal = Productos::Producto.where(id: 2).first
        veg = Productos::Producto.where(id: 3).first
        1..40.times do |i|
          MenusDiarios::MenuDiario.create! producto: heavy, fecha: 15.days.ago+i.days, descripcion: ['Ensalada Caesar Light', 'Arroz Blanco con Pollo al Grillé', 'Bifes con Puré y Ensalada', 'Tortilla de Papa y Milanesa de Soja'].sample, autor: Usuarios::Usuario.first if heavy.present?
          MenusDiarios::MenuDiario.create! producto: sal, fecha: 15.days.ago+i.days, descripcion: ['Ensalada de lechuga y queso blanco', 'Arroz Blanco y Huevo', 'Puré de Palta y hamburguesa', 'Tortilla de Verengenitas al Verdeo'].sample, autor: Usuarios::Usuario.first if sal.present?
          MenusDiarios::MenuDiario.create! producto: veg, fecha: 15.days.ago+i.days, descripcion: ['Queso Chedar Light', 'Pure sin Sal', 'Salmón al vino Tinto y Pure de Papa', 'Tortilla Holandesa con Huevos Tomahawk'].sample, autor: Usuarios::Usuario.first if veg.present?
        end

      t1 = Tiendas::Tienda.create! nombre: 'Catering Solutions', carrito_de_compras: true, despachos: true, dominio: 'cateringsolutions.com.ar', video_ayuda: 'https://www.youtube.com/embed/sp1X_1ibAzc'

      t2 = Tiendas::Tienda.create! nombre: 'Tivoglio', venta_mostrador: true, dominio: 'tivoglio.com.ar', color_fondo_logo: '#61de66', color_de_menu: '#61de66', color_barra_superior: '#2bc13f', color_titulo: '#696969', color_barra_filtros: '#c1bbb3', color_links_hover: '#0045e6', color_links: '#0096d6', color_de_fondo: '#ffffff'

      p1 = Clientes::Cliente.create! nombre: 'Cliente Interno', cuit: '20294834487', domicilio: 'Catering Casa Central', telefono: '3492431442', email: 'mtincho342@gmail.com', dia_inicio_ciclo_facturacion: 1, vencimiento_a: 1, horario_corte_pedidos: '21:00', tienda: t1
      p1.cuentas.build cliente: p1, nombre: 'Cuenta Compras Internas'
      p1.save!

      d = Usuarios::Usuario.create_or_update_by :login, login: 'dev', nombre: 'Administrador', password: 'hipopotamo', password_confirmation: 'hipopotamo', rol: :admin, dni: 29483448, tipo_usuario_id: 2, tiendas: [t1, t2]
      guille = adm = Usuarios::Usuario.create_or_update_by :login, login: 'admin', nombre: 'Guille', password: 'claveadmin', password_confirmation: 'claveadmin', rol: :admin, dni: 29483447, tipo_usuario_id: 2, tiendas: [t1]
      Usuarios::Usuario.create_or_update_by :login, login: 'sistema', nombre: 'Sistema', password: '361a4zfcut', password_confirmation: '361a4zfcut', rol: :robot, discontinued_at: nil, dni: 29483449, tipo_usuario_id: 2

      guille.documentos.create!(autor: guille,documento: File.open(Rails.root.join("db/migrate/imagenes/guille.png")))
      d.documentos.create!(autor: d,documento: File.open(Rails.root.join("db/migrate/imagenes/dev.jpg")))

      ae = Usuarios::Usuario.create_or_update_by :login, login: 'admin_cliente_interno', nombre: 'Admin de Empresa', password: 'admin_cliente_interno', password_confirmation: 'admin_cliente_interno', rol: :administrador_empresa, discontinued_at: nil, cuenta: p1.cuenta_principal, dni: 29483441, tipo_usuario_id: 1, tienda_cliente: t1
      autor = Usuarios::Usuario.create_or_update_by :login, login: 'comprador', nombre: 'Catering', password: 'comprador', password_confirmation: 'comprador', rol: :comprador, discontinued_at: nil, cuenta: p1.cuentas.second, dni: 29483440, tipo_usuario_id: 1, tienda_cliente: t1
      autor2 = Usuarios::Usuario.create_or_update_by :login, login: 'comprador2', nombre: 'Consumidor Final', password: 'comprador2', password_confirmation: 'comprador2', rol: :comprador, discontinued_at: nil, cuenta: p1.cuenta_principal, dni: 29483444, tipo_usuario_id: 1, tienda_cliente: t1

      Productos::Categoria.create! nombre: "Menús del Dia", descripcion: "Menús Diarios", menu_diario: true, tienda: t1
      Productos::Categoria.create! nombre: "Sandwiches", descripcion: "Sandwiches", tienda: t1
      Productos::Categoria.create! nombre: "Opciones Frías", descripcion: "Sandwiches", tienda: t1
      Productos::Categoria.create! nombre: "Ensaladas", descripcion: "Ensaladas", tienda: t1
      Productos::Categoria.create! nombre: "Opciones con Pastas", descripcion: "Pastas", tienda: t1
      Productos::Categoria.create! nombre: "Opciones con Masas", descripcion: "Masas", tienda: t1
      Productos::Categoria.create! nombre: "Opciones Bajas Calorías", descripcion: "Opciones Bajas Calorías", tienda: t1
      Productos::Categoria.create! nombre: "Opciones Calóricas", descripcion: "Opciones Calóricas", tienda: t1
      Productos::Categoria.create! nombre: "Otros", descripcion: "Otros", tienda: t1

      colores = ['#ff7b25', '#ffcc5c', '#82b74b', '#d96459', '#588c7e', '#d9ad7c', '#ff2b2f', '#d77bf5']

      Productos::Producto.reset_column_information

      ['Menú Calórico', 'Menú Saludable', 'Menú Veggie'].each_with_index do |pr, i|
        a = Productos::Producto.new nombre: pr, tienda:t1, categoria_id: 1, codigo: "MEN00#{i+1}", descripcion: " #{pr} del día", color: colores.sample
        a.precios.build importe: 150, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

        cod_sand = "SAN001
        SAN002
        SAN003
        SAN004
        SAN005
        SAN006
        SAN007
        SAN008
        SAN009
        SAN010
        SAN011
        SAN012
        SAN013
        SAN014
        SAN015
        SAN016
        SAN017
        SAN018
        SAN019
        SAN020"

        desc_sand = "Pebete de bondiola (varilla de pan francés de 20 cm aprox. con bondiola y queso)
      Pebete jamón crudo (varillas de pan francés de 20 cm aprox. con jamón crudo y queso)
      Pebete milan (varillas de pan francés de 20 cm aprox. con milán y queso)
      Pebete mortadela (varilla de pan francés de 20 cm aprox. con mortadela y queso)
      Pebete paleta (varilla de pan francés de 20 cm aprox. con de paleta y queso)
      Sandwich de miga especial con Atún x 4 unidades (pan de miga, atun y mayonesa)
      Sandwich de miga triple de pollo x 4 unidades (pan de miga, pasta de pollo, tomate, mayonesa)
      Sándwich de Milanesa con jamón y queso (varilla de pan francés de 20 cm aprox. con milanesa de ternera, jamón y queso)
      Sandwich de Suprema con jamón y queso (varilla de pan francés de 20 cm aprox. Con suprema de pollo, jamón y queso)
      Sándwich de pan árabe con atún (Atún, jamón, queso, aceitunas, tomate y huevo duro)
      Sándwich de pan árabe con pollo (Pollo, jamón, queso, tomate, lechuga y huevo duro)
      Sándwich de pan árabe vegertariano (Queso, zanahoria, lechuga, tomate, aros de cebolla y huevo duro)
      Sandwich de pan lactal de salvado triple con atún (atún, queso y mayonesa)
      Sandwich gourmet (pan con semillas, jamón crudo, rúcula y queso crema)
      Sándwich lactal blanco (pan lactal, jamón, queso, lechuga y tomate)
      Sándwich lactal negro (pan lactal, jamón, queso, lechuga y tomate)
      Sándwich miga  Triple de jamón y queso x4 (pan de miga, jamón, queso y mayonesa)
      Sándwich miga primavera (pan de miga, jamón, queso, lechuga, tomate y mayonesa)
      Sandwich super completo de milanesa (varilla de pan francés de 20 cm aprox., milanesa de ternera, jamón, queso, lechuga y aderezo )
      Sandwich super completo de suprema (varilla de pan francés de 20 cm aprox., suprema de pollo, jamón, queso, lechuga y aderezo )"

      precio_sand = "$ 83,58
      $ 83,58
      $ 74,79
      $ 70,39
      $ 72,59
      $ 131,97
      $ 131,97
      $ 135,48
      $ 135,48
      $ 129,78
      $ 129,78
      $ 114,38
      $ 75,89
      $ 92,38
      $ 54,99
      $ 65,99
      $ 124,32
      $ 127,51
      $ 143,45
      $ 143,45"
      prods_sand = desc_sand.split("\n").map(&:strip)
      prex_sand = precio_sand.gsub('$ ', '').split("\n").map(&:strip)
      cod_sand.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_sand[i].split('(')[0].capitalize, categoria_id: 2, tienda: t1, descripcion: prods_sand[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize
        a.precios.build importe: prex_sand[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

        cod_fr = "FR001
          FR003
          FR004
          FR005
          FR006"

        desc_fr = "Antón chileno (Torre de creps, mayonesa, jamón, queso, morrones y aceitunas)
  Mayonesa de ave (papa, zanahoria, pollo y mayonesa)
  Pionono de atún, tomate y huevo duro
  Pionono primavera (Pionono, mayonesa, jamón, queso, huevo duro, morrones y aceitunas)
  Roll de verano (Crep, pollo con mayonesa, jamón, queso, morrones, aceitunas, lechuga, tomate y huevo duro)"

      precio_fr = "$ 114,38
  $ 87,98
  $ 120,98
  $ 98,98
  $ 125,38"
      prods_fr = desc_fr.split("\n").map(&:strip)
      prex_fr = precio_fr.gsub('$ ', '').split("\n").map(&:strip)
      cod_fr.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_fr[i].split('(')[0].capitalize, tienda: t1, categoria_id: 3, descripcion: (prods_fr[i].split('(')[1] ? prods_fr[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
        a.precios.build importe: prex_fr[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

      create_table "horarios" do |t|
        t.integer :position
        t.integer :tienda_id
        t.string "horario"
        t.string "nombre"
        t.boolean :predeterminado, null: false, default: false
        t.datetime :discontinued_at
      end
      add_index :horarios, :position
      add_index :horarios, :tienda_id
      add_index :horarios, :discontinued_at
      add_column :pedidos, :horario_id, :integer
      add_index :pedidos, :horario_id
      add_column :tiendas, :horarios_de_entrega, :boolean, default: false
      add_column :clientes, :horarios_de_entrega, :boolean, default: false
      Tiendas::Tienda.reset_column_information
      Clientes::Cliente.reset_column_information
      execute "update tiendas set horarios_de_entrega = true where id = 1"
      execute "update pedidos set horario_id = 1 where tienda_id = 1 and estado_id <> 1"
      Pedidos::Horario.create! nombre: 'Mañana', horario: '12:30hs', tienda_id: 1, predeterminado: true
      Pedidos::Horario.create! nombre: 'Tarde', horario: '19:00hs', tienda_id: 1

      ts = Productos::Producto.all
      30.times do |i|
        au = [ae, autor, autor2].sample
        Pedidos::Pedido.create! fecha: (i).days.since, autor: au, tienda: t1, usuario: au, productos_solicitados: [1,2,3].sample.times.map{|x| {cantidad: [1,2,3,6,9,5].sample, producto: ts.sample, observaciones_cliente: "Observacion cliente"}}, no_validar_fecha: true, horario_id: Pedidos::Horario.first.id
      end

    cod_en = "EN001
      EN002
      EN003
      EN004
      EN005
      EN006
      EN007
      EN008
      EN009
      EN010
      EN011
      EN013
      EN014
      EN015
      EN016
      EN017
      EN018
      EN019
      EN020
      EN021
      EN022
      EN023
      EN024
      EN025
      EN026
      EN027
      EN028
      EN029
      EN030
      EN031
      EN032
      EN033
      EN034
      EN035
      EN036
      EN037"
    desc_en = "Ensalada achicoria y huevo duro C19
      Ensalada achicoria, choclo, champignones, tomate, jamón y queso C22
      Ensalada arroz con atún (Arroz, atún, zanahoria y huevo duro) C15
      Ensalada arroz primavera (Arroz, choclo, arvejas, pimiento y huevo duro) C30
      Ensalada arroz, aceitunas, tomate y huevo duro C16
      Ensalada atún, lechuga y tomate C28
      Ensalada choclo, huevo, tomate y hojas verdes
      Ensalada de achicoria, tomate, repollo blanco y morado C23
      Ensalada de arroz integral, verdeo, atún, palta y semillas de sésamo C5
      Ensalada de Caesar (lechuga, panceta grillada, pollo grillado, crutones, queso y aderezos) C11
      Ensalada de chauchas, tomate y choclo C8
      Ensalada de lechuga repollada, zanahoria, rabanitos, jamón, queso y palmito C10
      Ensalada de lechuga, pasta seca, tomates en cubo, crutones, aceitunas, jamón y queso C12
      Ensalada de remolacha y huevo
      Ensalada de repollo morado, remolacha,apio y aceituna
      Ensalada de rúcula, atún, aceitunas y queso
      Ensalada de rúcula, cebollitas, queso azul, olivas negras y pan tostado
      Ensalada de rúcula, champignones y queso en hebras C2
      Ensalada de rúcula, chauchas, zanahoria rayada y champignones  C1
      Ensalada de rúcula, chauchas, zanahoria rayada, queso en hebras y palta C9
      Ensalada de rúcula, tomates, nueces, queso en hebras, calabaza y oliva negras C7
      Ensalada de zanahoria rayada, tomate en cubos y lechuga repollada
      Ensalada de zanahoria rayada,palmitos, choclo y pollo grillado C4
      Ensalada de zanahoria, tomate, apio, rabanito, nueces, lechuga y aceitunas C6
      Ensalada especial rúcula (Rúcula, parmesano, tomate y huevo duro) C25
      Ensalada lentejas, tomate y huevo duro C27
      Ensalada papa, chauchas, tomate y huevo duro C18
      Ensalada papa, choclo y huevo duro C17
      Ensalada pollo, ananá, palmitos, tomate y zanahoria  C13
      Ensalada pollo, jamón, queso, lechuga, tomate y huevo duro C26
      Ensalada pollo, papa y zanahoria C20
      Ensalada pollo, queso, Lechuga y huevo duro C29
      Ensalada primavera (Choclo, zanahoria, hojas verdes, tomate y huevo duro) C14
      Ensalada rúcula, lechuga y huevo duro C24
      Ensalada rusa (papa, zanahoria, arvejas y huevo duro) C21
      Ensalada Capresse (tomate, mozzarella y albahaca y olivas negras)"
    precio_en = "$ 90,32
      $ 114,76
      $ 98,82
      $ 73,05
      $ 97,55
      $ 130,17
      $ 92,05
      $ 90,85
      $ 114,76
      $ 135,48
      $ 105,58
      $ 115,96
      $ 133,89
      $ 95,63
      $ 100,42
      $ 135,48
      $ 119,54
      $ 119,54
      $ 119,54
      $ 124,32
      $ 135,48
      $ 102,81
      $ 129,11
      $ 131,50
      $ 102,81
      $ 83,68
      $ 100,99
      $ 100,42
      $ 130,83
      $ 131,50
      $ 105,20
      $ 119,54
      $ 109,98
      $ 119,54
      $ 79,70
      $ 96,40"
    prods_en = desc_en.split("\n").map(&:strip)
    prex_en = precio_en.gsub('$ ', '').split("\n").map(&:strip)
    cod_en.split("\n").map(&:strip).each_with_index do |c, i|
      a = Productos::Producto.new nombre: prods_en[i].split('(')[0].capitalize, tienda: t1, categoria_id: 4, descripcion: (prods_en[i].split('(')[1] ? prods_en[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
      a.precios.build importe: prex_en[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
      a.save!
    end

    cod_ms = "EMP001
      EMP002
      EMP003
      EMP004
      EMP005
      EMP006
      EMP007
      EMP008
      EMP009
      EMP010
      EMP011
      EMP013
      EMP014
      EMP015
      EMP016
      EMP017
      EMP018
      EMP019
      EMP020
      EMP021
      EMP022
      EMP023
      EMP024
      EMP025
      EMP026
      EMP027
      EMP028
      EMP029"

    desc_ms = "Calzone (Masa casera, salsa de pizza, jamón, queso, cebolla, morrones, huevo duro)
      Empanadas acelga x 3
      Empanadas árabes x 3
      Empanadas carne x 3
      Empanadas cebolla y queso x 3
      Empanadas jamón y queso x 3
      Empanadas pescado x 3
      Empanadas pollo x 3
      Pascualina Capresse (queso, tomate y albahaca)
      Pascualina de acelga
      Pascualina de pollo y verduras (pollo, pimiento, cebolla, zanahoria y zapallito)
      Pascualina jamón, queso y tomate
      Roll Capresse (masa casera, queso, tomate, albahaca y olivas negras)
      Roll de atún (masa casera, morrones, queso tybo y lomitos de atún)
      Roll de jamón y queso ( masa casera, jamón, queso, morrones y aceitunas)
      Roll de pollo (masa casera, morrones, queso y pollo)
      Roll de ternera (masa casera, morrones, queso y ternera)
      Roll de vegetales (masa casera, morrones, queso, tomate y huevo)
      Tarta Capresse (queso, tomate, albahaca y olivas negras)
      Tarta de 4 Quesos
      Tarta de acelga (cebolla, queso, pimiento y acelga)
      Tarta de calabaza (calabaza, cebolla y queso)
      Tarta de cebolla y queso
      Tarta de choclo (cebolla, pimiento, salsa blanca, choclo y queso)
      Tarta de jamón y queso
      Tarta de verduras (pimiento,cebolla,zanahoria y zapallito)
      Tarta de zapallitos (zapallitos y queso)
      Tartines con masa integral (2 mini tartas de sabores frescos y combinados) Opciones: brocoli, calabaza y acelga."

    precio_ms = "$ 114,38
      $ 100,42
      $ 100,42
      $ 100,42
      $ 100,42
      $ 100,42
      $ 105,20
      $ 105,20
      $ 109,98
      $ 118,78
      $ 109,98
      $ 109,98
      $ 127,58
      $ 143,45
      $ 127,58
      $ 127,58
      $ 131,97
      $ 127,58
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 90,18
      $ 119,54"
      prods_ms = desc_ms.split("\n").map(&:strip)
      prex_ms = precio_ms.gsub('$ ', '').split("\n").map(&:strip)
      cod_ms.split("\n").map(&:strip).each_with_index do |c, i|
      a = Productos::Producto.new nombre: prods_ms[i].split('(')[0].capitalize, tienda: t1, categoria_id: 6, descripcion: (prods_ms[i].split('(')[1] ? prods_ms[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
      a.precios.build importe: prex_ms[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
      a.save!
      end

      cod_ps = "INV001
        INV002
        INV003
        INV004
        INV005
        INV006
        INV007
        INV008
        INV009
        INV010"

      desc_ps = "Arroz blanco hervido
        Arroz con pollo y queso rayado
        Arroz integral hervido
        Canelones de carne y verdura con salsa bolognesa y queso rayado
        Lasagna
        Ñoquis con tuco, crema y queso rayado
        Polenta con salsa bolognesa y queso rayado
        Ravioles de carne y verdura  con salsa bolognesa y queso rayado
        Tallarines con crema
        Tallarines con tuco, peceto y queso rayado"

      precio_ps = "$ 59,39
        $ 146,11
        $ 76,99
        $ 146,11
        $ 146,11
        $ 146,11
        $ 130,17
        $ 146,11
        $ 130,17
        $ 146,11"

      prods_ps = desc_ps.split("\n").map(&:strip)
      prex_ps = precio_ps.gsub('$ ', '').split("\n").map(&:strip)
      cod_ps.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_ps[i].split('(')[0].capitalize, tienda: t1, categoria_id: 5, descripcion: (prods_ps[i].split('(')[1] ? prods_ps[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
        a.precios.build importe: prex_ps[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

      cod_bc = "OBC002
        OBC003
        OBC004
        OBC005
        OBC009
        OBC010
        OBC011
        OBC012
        OBC013
        OBC014
        OBC015
        OBC016
        OBC017
        OBC018
        OBC019
        OBC020
        OBC021
        OBC022
        OBC023
        OBC025
        OBC026"

      desc_bc = "Berenjenas a la napolitana con puré
        Berenjenas rellenas con arróz
        Chopsuey (cebolla,pimiento rojo, pimiento verde; pollo, calabaza, berenjena y arroz)
        Hamburguesas de merluza al horno (2 unidades)
        Milanesa de soja a la pizza (2 unidades)
        Milanesas de merluza al horno (aprox 200 grs)
        Milanesas de ternera al horno (Aprox 250 grs)
        Omelette de vegetales y queso (huevo, queso, zapallito, pimiento y zanahoria)
        Pollo grillado (Filet de pechuga a la plancha)
        Puré de calabaza
        Supremas al horno ( Aprox. 250 grs)
        Torre de berenjenas a la napolitana
        Tortilla de acelga
        Tortilla de cebollas
        Tortilla de papa y cebolla
        Tortilla de vegetales (zapallito, zanahoria, pimiento y huevo)
        Tortilla de verduras (acelga,cebolla, queso y pimiento)
        Tortilla de zapallitos
        Verduras al horno
        Verduras salteadas al wok
        Zapallitos rellenos con vegetales (2 unidades)"

      precio_bc = "$ 120,98
        $ 120,98
        $ 130,17
        $ 109,98
        $ 103,60
        $ 114,38
        $ 106,26
        $ 87,98
        $ 109,98
        $ 72,59
        $ 106,26
        $ 109,98
        $ 80,33
        $ 80,33
        $ 80,33
        $ 80,33
        $ 80,33
        $ 80,33
        $ 87,98
        $ 92,38
        $ 109,98"

      prods_bc = desc_bc.split("\n").map(&:strip)
      prex_bc = precio_bc.gsub('$ ', '').split("\n").map(&:strip)
      cod_bc.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_bc[i].split('(')[0].capitalize, tienda: t1, categoria_id: 7, descripcion: (prods_bc[i].split('(')[1] ? prods_bc[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
        a.precios.build importe: prex_bc[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

      cod_c = "OC001
        OC002
        OC005
        OC006
        OC012
        OC013
        OC014
        OC015
        OC016
        OC017
        OC018
        OC020"

      desc_c = "Bifes a la criolla (bifes de ternera con cebollo, pimiento, zanhoria y papas)
        Churrasquito de cerdo con papas
        Hamb. De carne gratinadas (hamburguesa con queso) x 2 unidades
        Hamburguesas de pollo x 2 unidades
        Milanesa de ternera a la pizza
        Suprema (250 grs aprox)
        Milanesa (250 grs aprox)
        Omellette de jamón y queso
        Pizza casera especial (4 porciones, salsa de pizza, muzzarella, jamón y morrones)
        Pizza casera muzzarella (4 porciones, salsa de pizza, muzzarella y orégano)
        Puré de papas
        Tortilla de papa rellena (jamón, queso y tomate)"

      precio_c = "$ 146,11
        $ 153,97
        $ 120,98
        $ 109,98
        $ 114,38
        $ 106,26
        $ 106,26
        $ 126,18
        $ 105,58
        $ 101,18
        $ 79,70
        $ 103,60"

      prods_c = desc_c.split("\n").map(&:strip)
      prex_c = precio_c.gsub('$ ', '').split("\n").map(&:strip)
      cod_c.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_c[i].split('(')[0].capitalize, tienda: t1, categoria_id: 8, descripcion: (prods_c[i].split('(')[1] ? prods_c[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
        a.precios.build importe: prex_c[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end

      cod_o = "OTR001
        OTR002
        OTR004"

      desc_o = "Ensalada de Frutas chica (peso aprox. 210 g)
        Ensalada de Frutas grande (peso aprox. 390 g)
        Frutas"

      precio_o = "$ 38,85
        $ 76,65
        $ 27,30"

      prods_o = desc_o.split("\n").map(&:strip)
      prex_o = precio_o.gsub('$ ', '').split("\n").map(&:strip)
      cod_o.split("\n").map(&:strip).each_with_index do |c, i|
        a = Productos::Producto.new nombre: prods_o[i].split('(')[0].capitalize, tienda: t1, categoria_id: 9, descripcion: (prods_o[i].split('(')[1] ? prods_o[i].split('(')[1].gsub('(', '').gsub(')', '').capitalize : nil)
        a.precios.build importe: prex_o[i].to_f.ceil, fecha_desde: 0.days.ago, fecha_hasta: (Time.zone.today+1.month).end_of_month, producto: a
        a.save!
      end


        Pedidos::Pedido.order('fecha asc').each do |t|
          t.confirmar if t.fecha.to_date < Time.zone.today-1.day || (t.fecha.to_date <= Time.zone.today-1.day )
        end

        Comprobantes::Comprobante.find_each{|x| x.confirmar!(Usuarios::Usuario.find_by_login('admin')) }


      [
        { modulo: 'Usuarios', nombre: 'super_admin', titulo: 'Super Administrador', descripcion: 'Administrador general que puede crear nuevas tiendas y asignar tiendas a administradores.'  }
      ].each { |attrs| Usuarios::Rol.create_or_update_by :nombre, attrs }

      Usuarios::Usuario.where(id: [1,2]).each do |u|
        u.tienda_ids = [1]
        u.save!
      end

      Usuarios::Usuario.create_or_update_by :login, login: 'tivo', nombre: 'Administrador', password: 'clavesana', password_confirmation: 'clavesana', rol: :admin, tipo_usuario_id: 2, tiendas: [t2], dni: 2342420

      Clientes::Cliente.create! nombre: 'Consumidor Final', cuit: '00000000000', tienda_id: 2
      Tiendas::Tienda.first.documentos.create!(autor: Usuarios::Usuario.first,documento: File.open(Rails.root.join("db/migrate/imagenes/fondo.jpg")))
      Tiendas::Tienda.second.documentos.create!(autor: Usuarios::Usuario.first,documento: File.open(Rails.root.join("db/migrate/imagenes/fondoti.jpg")))
    end
  end
end
