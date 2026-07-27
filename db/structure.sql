/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.13-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: kiosk_development
-- ------------------------------------------------------
-- Server version	10.11.9-MariaDB-ubu2204

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `afectaciones`
--

DROP TABLE IF EXISTS `afectaciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `afectaciones` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `comprobante_id` int(11) DEFAULT NULL,
  `afectado_id` int(11) DEFAULT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT 0.00,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_afectaciones_on_afectado_id` (`afectado_id`) USING BTREE,
  KEY `index_afectaciones_on_comprobante_id` (`comprobante_id`) USING BTREE,
  KEY `index_afectaciones_on_created_at` (`created_at`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=133580 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `answeres`
--

DROP TABLE IF EXISTS `answeres`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `answeres` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `question_id` bigint(20) DEFAULT NULL,
  `text` varchar(255) DEFAULT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_answeres_on_question_id` (`question_id`),
  CONSTRAINT `fk_rails_7d4e5e1fc3` FOREIGN KEY (`question_id`) REFERENCES `questiones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ar_internal_metadata`
--

DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `categorias`
--

DROP TABLE IF EXISTS `categorias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `categorias` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `codigo` int(11) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `menu_diario` tinyint(1) NOT NULL DEFAULT 0,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `grupo_cocina_id` int(11) DEFAULT NULL,
  `stock_activo` tinyint(1) NOT NULL DEFAULT 0,
  `vender_en_carrito` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `index_categorias_on_discontinued_at` (`discontinued_at`),
  KEY `index_categorias_on_nombre` (`nombre`),
  KEY `index_categorias_on_codigo` (`codigo`) USING BTREE,
  KEY `index_categorias_on_tienda_id` (`tienda_id`)
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes`
--

DROP TABLE IF EXISTS `clientes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `cuit` varchar(255) DEFAULT NULL,
  `ciudad` varchar(255) DEFAULT NULL,
  `domicilio` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `nro_inscripcion_iibb` varchar(15) DEFAULT NULL,
  `telefono` varchar(255) DEFAULT NULL,
  `dia_inicio_ciclo_facturacion` int(11) NOT NULL DEFAULT 1,
  `vencimiento_a` int(11) NOT NULL DEFAULT 15,
  `horario_corte_pedidos` varchar(255) NOT NULL DEFAULT '00:00',
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `permitir_envios_a_domicilio` tinyint(1) DEFAULT 0,
  `codigo_externo_en_etiquetas` tinyint(1) DEFAULT 0,
  `usuario_puede_elegir_cuenta` tinyint(1) NOT NULL DEFAULT 0,
  `mostrar_cuentas_corrientes` tinyint(1) NOT NULL DEFAULT 0,
  `cuenta_corriente` tinyint(1) DEFAULT 1,
  `horarios_de_entrega` tinyint(1) DEFAULT 0,
  `listas_de_precio_privada` tinyint(1) NOT NULL DEFAULT 0,
  `limite_compra_pesos` decimal(10,2) DEFAULT NULL,
  `limite_compra_dolares` decimal(10,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_clientes_on_discontinued_at` (`discontinued_at`),
  KEY `index_clientes_on_cuit` (`cuit`),
  KEY `index_clientes_on_nombre` (`nombre`),
  KEY `index_clientes_on_horario_corte_pedidos` (`horario_corte_pedidos`)
) ENGINE=InnoDB AUTO_INCREMENT=107 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes_categorias`
--

DROP TABLE IF EXISTS `clientes_categorias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes_categorias` (
  `cliente_id` int(11) DEFAULT NULL,
  `categoria_id` int(11) DEFAULT NULL,
  KEY `index_clientes_categorias_on_categoria_id` (`categoria_id`),
  KEY `index_clientes_categorias_on_cliente_id` (`cliente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes_pedidos_cocina`
--

DROP TABLE IF EXISTS `clientes_pedidos_cocina`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes_pedidos_cocina` (
  `pedido_cocina_id` bigint(20) NOT NULL,
  `cliente_id` bigint(20) NOT NULL,
  KEY `index_clientes_pedidos_cocina_on_pedido_cocina_id` (`pedido_cocina_id`),
  KEY `index_clientes_pedidos_cocina_on_cliente_id` (`cliente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes_precios`
--

DROP TABLE IF EXISTS `clientes_precios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes_precios` (
  `cliente_id` int(11) DEFAULT NULL,
  `precio_id` int(11) DEFAULT NULL,
  KEY `index_clientes_precios_on_precio_id` (`precio_id`),
  KEY `index_clientes_precios_on_cliente_id` (`cliente_id`),
  KEY `index_clientes_precios_on_precio_cliente` (`precio_id`,`cliente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes_tiendas`
--

DROP TABLE IF EXISTS `clientes_tiendas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes_tiendas` (
  `cliente_id` bigint(20) NOT NULL,
  `tienda_id` bigint(20) NOT NULL,
  UNIQUE KEY `index_clientes_tiendas_uniq` (`cliente_id`,`tienda_id`),
  KEY `index_clientes_tiendas_on_cliente_id` (`cliente_id`),
  KEY `index_clientes_tiendas_on_tienda_id` (`tienda_id`),
  KEY `index_clientes_tiendas_reverse` (`tienda_id`,`cliente_id`),
  CONSTRAINT `fk_rails_0cab44d15e` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`),
  CONSTRAINT `fk_rails_d92155328e` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clientes_turnos_entrega`
--

DROP TABLE IF EXISTS `clientes_turnos_entrega`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clientes_turnos_entrega` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cliente_id` bigint(20) NOT NULL,
  `turno_entrega_id` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_clientes_turnos_on_cliente_and_turno` (`cliente_id`,`turno_entrega_id`),
  KEY `index_clientes_turnos_entrega_on_cliente_id` (`cliente_id`),
  KEY `index_clientes_turnos_entrega_on_turno_entrega_id` (`turno_entrega_id`),
  CONSTRAINT `fk_rails_22f3292f8e` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`),
  CONSTRAINT `fk_rails_ce4ea38d20` FOREIGN KEY (`turno_entrega_id`) REFERENCES `turnos_entrega` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comprobantes`
--

DROP TABLE IF EXISTS `comprobantes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `comprobantes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `tipo_id` bigint(20) DEFAULT NULL,
  `pedido_id` bigint(20) DEFAULT NULL,
  `cuenta_id` bigint(20) DEFAULT NULL,
  `estado_id` int(11) DEFAULT 1,
  `fecha_emision` datetime DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `nro` int(11) DEFAULT NULL,
  `total` decimal(12,2) NOT NULL DEFAULT 0.00,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `generado_por_id` int(11) DEFAULT NULL,
  `autor_id` bigint(20) DEFAULT NULL,
  `contabilizado_el` datetime DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `evento_id` int(11) DEFAULT NULL,
  `automatico` tinyint(1) NOT NULL DEFAULT 0,
  `bonificacion` int(11) NOT NULL DEFAULT 0,
  `historial_id` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `local_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_comp_on_tienda_id_tc_nro` (`tienda_id`,`tipo_id`,`nro`) USING BTREE,
  KEY `index_comprobantes_on_tipo_id` (`tipo_id`),
  KEY `index_comprobantes_on_pedido_id` (`pedido_id`),
  KEY `index_comprobantes_on_cuenta_id` (`cuenta_id`),
  KEY `index_comprobantes_on_autor_id` (`autor_id`),
  KEY `index_comprobantes_on_contabilizado_el` (`contabilizado_el`) USING BTREE,
  KEY `index_comprobantes_on_descripcion` (`descripcion`) USING BTREE,
  KEY `index_comprobantes_on_estado_id` (`estado_id`) USING BTREE,
  KEY `index_comprobantes_on_evento_id` (`evento_id`) USING BTREE,
  KEY `index_comprobantes_on_fecha_emision` (`fecha_emision`) USING BTREE,
  KEY `index_comprobantes_on_generado_por_id` (`generado_por_id`) USING BTREE,
  KEY `index_comprobantes_on_historial_id` (`historial_id`) USING BTREE,
  KEY `index_comprobantes_on_nro` (`nro`) USING BTREE,
  KEY `index_comprobantes_on_type` (`type`) USING BTREE,
  KEY `index_comprobantes_on_updated_at` (`updated_at`) USING BTREE,
  KEY `index_comprobantes_on_tienda_id` (`tienda_id`),
  KEY `index_comprobantes_on_tc_nro` (`tipo_id`,`nro`) USING BTREE,
  KEY `index_comprobantes_on_local_id` (`local_id`),
  KEY `idx_comprobantes_cuenta_estado_fecha_emision` (`cuenta_id`,`estado_id`,`fecha_emision`),
  KEY `idx_comprobantes_tienda_estado_type_fecha_emision` (`tienda_id`,`estado_id`,`type`,`fecha_emision`),
  KEY `idx_comprobantes_tienda_local_estado_type_fecha` (`tienda_id`,`local_id`,`estado_id`,`type`,`fecha_emision`)
) ENGINE=InnoDB AUTO_INCREMENT=653689 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `comprobantes_asociados`
--

DROP TABLE IF EXISTS `comprobantes_asociados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `comprobantes_asociados` (
  `comprobante_id` int(11) DEFAULT NULL,
  `asociado_id` int(11) DEFAULT NULL,
  KEY `index_comprobantes_asociados_on_asociado_id` (`asociado_id`),
  KEY `index_comprobantes_asociados_on_comprobante_id` (`comprobante_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `configuraciones_impositivas`
--

DROP TABLE IF EXISTS `configuraciones_impositivas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `configuraciones_impositivas` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `cliente_id` int(11) DEFAULT NULL,
  `impuesto_id` int(11) DEFAULT NULL,
  `condicion_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_configuraciones_impositivas_on_condicion_id` (`condicion_id`) USING BTREE,
  KEY `index_configuraciones_impositivas_on_cliente_id` (`cliente_id`) USING BTREE,
  KEY `index_configuraciones_impositivas_on_impuesto_id` (`impuesto_id`) USING BTREE,
  KEY `index_configuraciones_impositivas_on_type` (`type`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cotizaciones_dolar`
--

DROP TABLE IF EXISTS `cotizaciones_dolar`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cotizaciones_dolar` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `fecha` date NOT NULL,
  `precio_venta` decimal(10,2) NOT NULL,
  `precio_compra` decimal(10,2) DEFAULT NULL,
  `fuente` varchar(255) NOT NULL DEFAULT 'oficial',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cotizaciones_dolar_on_fecha` (`fecha`)
) ENGINE=InnoDB AUTO_INCREMENT=2329 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cuentas`
--

DROP TABLE IF EXISTS `cuentas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cuentas` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nro` int(11) DEFAULT NULL,
  `nombre` varchar(255) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `cliente_id` bigint(20) DEFAULT NULL,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `cuenta_corriente_parcial` tinyint(1) DEFAULT NULL,
  `horario_corte_pedidos` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cuentas_on_nro_unique` (`nro`),
  KEY `index_cuentas_on_cliente_id` (`cliente_id`),
  KEY `index_cuentas_clientes_on_nombre` (`nombre`) USING BTREE,
  KEY `index_cuentas_clientes_on_position` (`position`) USING BTREE,
  KEY `index_cuentas_on_horario_corte_pedidos` (`horario_corte_pedidos`)
) ENGINE=InnoDB AUTO_INCREMENT=171 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cuentas_pedidos_cocina`
--

DROP TABLE IF EXISTS `cuentas_pedidos_cocina`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cuentas_pedidos_cocina` (
  `pedido_cocina_id` bigint(20) NOT NULL,
  `cuenta_id` bigint(20) NOT NULL,
  KEY `index_cuentas_pedidos_cocina_on_pedido_cocina_id` (`pedido_cocina_id`),
  KEY `index_cuentas_pedidos_cocina_on_cuenta_id` (`cuenta_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cupones`
--

DROP TABLE IF EXISTS `cupones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cupones` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `codigo` varchar(255) NOT NULL,
  `tienda_id` bigint(20) DEFAULT NULL,
  `tipo_descuento` varchar(255) NOT NULL DEFAULT 'importe',
  `importe` decimal(10,2) DEFAULT NULL,
  `porcentaje` decimal(5,2) DEFAULT NULL,
  `limite_bonificacion` decimal(10,2) DEFAULT NULL,
  `fecha_vencimiento` date DEFAULT NULL,
  `utilizado` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `grupo` varchar(255) DEFAULT NULL,
  `cancelado` tinyint(1) NOT NULL DEFAULT 0,
  `nombre` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cupones_on_codigo` (`codigo`),
  KEY `index_cupones_on_tienda_id` (`tienda_id`),
  KEY `index_cupones_on_fecha_vencimiento` (`fecha_vencimiento`),
  KEY `index_cupones_on_utilizado` (`utilizado`),
  KEY `index_cupones_on_grupo` (`grupo`),
  KEY `index_cupones_on_cancelado` (`cancelado`),
  CONSTRAINT `fk_rails_7025a3ac97` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `delayed_jobs`
--

DROP TABLE IF EXISTS `delayed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `delayed_jobs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `priority` int(11) NOT NULL DEFAULT 0,
  `attempts` int(11) NOT NULL DEFAULT 0,
  `handler` text NOT NULL,
  `last_error` text DEFAULT NULL,
  `run_at` datetime DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `failed_at` datetime DEFAULT NULL,
  `locked_by` varchar(255) DEFAULT NULL,
  `queue` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `delayed_jobs_priority` (`priority`,`run_at`)
) ENGINE=InnoDB AUTO_INCREMENT=178012 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `descuentos_venta_mostrador`
--

DROP TABLE IF EXISTS `descuentos_venta_mostrador`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `descuentos_venta_mostrador` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `tienda_id` bigint(20) NOT NULL,
  `nombre` varchar(255) NOT NULL,
  `tipo_descuento` varchar(255) NOT NULL DEFAULT 'porcentaje',
  `porcentaje` decimal(5,2) DEFAULT NULL,
  `importe` decimal(12,2) DEFAULT NULL,
  `limite_bonificacion` decimal(12,2) DEFAULT NULL,
  `medio_pago_tipo` varchar(255) NOT NULL DEFAULT '',
  `importe_minimo` decimal(12,2) NOT NULL DEFAULT 0.00,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_descuentos_venta_mostrador_on_tienda_id` (`tienda_id`),
  KEY `index_descuentos_venta_mostrador_on_activo` (`activo`),
  KEY `index_descuentos_venta_mostrador_on_medio_pago_tipo` (`medio_pago_tipo`),
  CONSTRAINT `fk_rails_c77d9b7c5c` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `descuentos_venta_mostrador_clientes`
--

DROP TABLE IF EXISTS `descuentos_venta_mostrador_clientes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `descuentos_venta_mostrador_clientes` (
  `descuento_venta_mostrador_id` bigint(20) NOT NULL,
  `cliente_id` bigint(20) NOT NULL,
  UNIQUE KEY `idx_descuentos_vm_clientes_unique` (`descuento_venta_mostrador_id`,`cliente_id`),
  KEY `idx_descuentos_vm_cliente_id` (`cliente_id`),
  CONSTRAINT `fk_rails_00adedce54` FOREIGN KEY (`cliente_id`) REFERENCES `clientes` (`id`),
  CONSTRAINT `fk_rails_55ee52e28b` FOREIGN KEY (`descuento_venta_mostrador_id`) REFERENCES `descuentos_venta_mostrador` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `documentos`
--

DROP TABLE IF EXISTS `documentos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `documentos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `documentable_id` int(11) DEFAULT NULL,
  `documentable_type` varchar(255) DEFAULT NULL,
  `documento_file_name` varchar(255) DEFAULT NULL,
  `documento_content_type` varchar(255) DEFAULT NULL,
  `documento_file_size` int(11) DEFAULT NULL,
  `documento_updated_at` datetime DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `autor_id` int(11) DEFAULT NULL,
  `observaciones` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_imagenes_on_autor_id` (`autor_id`),
  KEY `index_documentos_on_documentable_id_and_documentable_type` (`documentable_id`,`documentable_type`),
  KEY `index_documentos_on_migrado_and_imagen_id_and_documentable_type` (`documentable_type`),
  KEY `index_documentos_on_position` (`position`)
) ENGINE=InnoDB AUTO_INCREMENT=1686 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `etiquetas_notificables`
--

DROP TABLE IF EXISTS `etiquetas_notificables`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `etiquetas_notificables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `etiquetado_id` int(11) DEFAULT NULL,
  `etiquetado_type` varchar(255) DEFAULT NULL,
  `etiquetador_id` int(11) DEFAULT NULL,
  `etiquetador_type` varchar(255) DEFAULT NULL,
  `nombre` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_etiquetas_notificables_on_etiquetado` (`etiquetado_id`,`etiquetado_type`),
  KEY `index_etiquetas_notificables_on_etiquetado_type` (`etiquetado_type`),
  KEY `index_etiquetas_notificables_on_etiquetable` (`etiquetador_id`,`etiquetador_type`),
  KEY `index_etiquetas_notificables_on_etiquetador_type` (`etiquetador_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `eventos`
--

DROP TABLE IF EXISTS `eventos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `eventos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `usuario_id` int(11) DEFAULT NULL,
  `origen_type` varchar(255) DEFAULT NULL,
  `origen_id` int(11) DEFAULT NULL,
  `fecha` datetime NOT NULL,
  `position` int(11) DEFAULT NULL,
  `estado_generado_id` int(11) DEFAULT NULL,
  `mensajes` text DEFAULT NULL,
  `interface` varchar(255) DEFAULT NULL,
  `nro_lote` varchar(255) DEFAULT NULL,
  `codigo_sobre_proveedor` varchar(255) DEFAULT NULL,
  `exitoso` tinyint(1) NOT NULL DEFAULT 0,
  `historial_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_eventos_on_estado_generado_id` (`estado_generado_id`) USING BTREE,
  KEY `index_eventos_on_fecha` (`fecha`) USING BTREE,
  KEY `index_eventos_on_historial_id` (`historial_id`) USING BTREE,
  KEY `index_eventos_on_origen_type_and_origen_id` (`origen_type`,`origen_id`) USING BTREE,
  KEY `index_eventos_on_position` (`position`) USING BTREE,
  KEY `index_eventos_on_type` (`type`) USING BTREE,
  KEY `index_eventos_on_usuario_id` (`usuario_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1004028 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `favoritos`
--

DROP TABLE IF EXISTS `favoritos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `favoritos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `usuario_id` bigint(20) DEFAULT NULL,
  `producto_id` bigint(20) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_favoritos_on_usuario_id` (`usuario_id`),
  KEY `index_favoritos_on_producto_id` (`producto_id`),
  KEY `index_favoritos_on_usuario_id_and_producto_id_and_updated_at` (`usuario_id`,`producto_id`,`updated_at`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=3007 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `feriados`
--

DROP TABLE IF EXISTS `feriados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `feriados` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `calendario_id` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_feriados_on_calendario_id` (`calendario_id`),
  KEY `index_feriados_on_fecha` (`fecha`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `generadores_secuenciales`
--

DROP TABLE IF EXISTS `generadores_secuenciales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `generadores_secuenciales` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `scope` varchar(50) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `ultimo` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_generadores_secuenciales_unique` (`scope`,`ultimo`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `grupos`
--

DROP TABLE IF EXISTS `grupos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `grupos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `discontinued_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_grupos_on_discontinued_at` (`discontinued_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `grupos_cocinas`
--

DROP TABLE IF EXISTS `grupos_cocinas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `grupos_cocinas` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `codigo` int(11) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_categorias_on_codigo` (`codigo`),
  KEY `index_categorias_on_nombre` (`nombre`),
  KEY `index_categorias_on_tienda_id` (`tienda_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `historiales`
--

DROP TABLE IF EXISTS `historiales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `historiales` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=653689 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `horarios`
--

DROP TABLE IF EXISTS `horarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `horarios` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `position` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `horario` varchar(255) DEFAULT NULL,
  `nombre` varchar(255) DEFAULT NULL,
  `predeterminado` tinyint(1) NOT NULL DEFAULT 0,
  `discontinued_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_horarios_on_position` (`position`),
  KEY `index_horarios_on_tienda_id` (`tienda_id`),
  KEY `index_horarios_on_discontinued_at` (`discontinued_at`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `imagenes`
--

DROP TABLE IF EXISTS `imagenes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `imagenes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `imaginable_id` int(11) DEFAULT NULL,
  `imaginable_type` varchar(255) DEFAULT NULL,
  `imagen_file_name` varchar(255) DEFAULT NULL,
  `imagen_content_type` varchar(255) DEFAULT NULL,
  `imagen_file_size` int(11) DEFAULT NULL,
  `imagen_updated_at` datetime DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `pie` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `locales`
--

DROP TABLE IF EXISTS `locales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `locales` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `domicilio` varchar(255) DEFAULT NULL,
  `telefono` varchar(255) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_locales_on_nombre` (`nombre`),
  KEY `index_locales_on_tienda_id` (`tienda_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `medios_pago`
--

DROP TABLE IF EXISTS `medios_pago`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `medios_pago` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `flujo_economico_id` int(11) DEFAULT NULL,
  `propio` tinyint(1) NOT NULL DEFAULT 1,
  `tipo_id` int(11) DEFAULT NULL,
  `nro` int(11) DEFAULT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT 0.00,
  `cuenta_id` int(11) DEFAULT NULL,
  `sucursal` int(11) DEFAULT NULL,
  `cp` int(11) DEFAULT NULL,
  `fecha_emision` date DEFAULT NULL,
  `fecha_presentacion` date DEFAULT NULL,
  `fecha_acreditacion` date DEFAULT NULL,
  `cuit` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `cuenta_bancaria_id` int(11) DEFAULT NULL,
  `fecha_retencion` date DEFAULT NULL,
  `pago_electronico_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_medios_pago_on_cuenta_bancaria_id` (`cuenta_bancaria_id`) USING BTREE,
  KEY `index_medios_pago_on_cuenta_id` (`cuenta_id`) USING BTREE,
  KEY `index_medios_pago_on_fecha_acreditacion` (`fecha_acreditacion`) USING BTREE,
  KEY `index_medios_pago_on_fecha_emision` (`fecha_emision`) USING BTREE,
  KEY `index_medios_pago_on_fecha_presentacion` (`fecha_presentacion`) USING BTREE,
  KEY `index_medios_pago_on_flujo_economico_id` (`flujo_economico_id`) USING BTREE,
  KEY `index_medios_pago_on_nro` (`nro`) USING BTREE,
  KEY `index_medios_pago_on_type` (`type`) USING BTREE,
  KEY `index_medios_pago_on_pago_electronico_id` (`pago_electronico_id`)
) ENGINE=InnoDB AUTO_INCREMENT=127689 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mensajes`
--

DROP TABLE IF EXISTS `mensajes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `mensajes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `autor_id` int(11) DEFAULT NULL,
  `asunto` varchar(255) DEFAULT NULL,
  `admite_comentarios` tinyint(1) DEFAULT 1,
  `cuerpo` text DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `recordar_el` datetime DEFAULT NULL,
  `recordar_a` varchar(255) DEFAULT 'a_mi',
  `duracion` int(11) DEFAULT 2,
  `mensaje_id` int(11) DEFAULT NULL,
  `respuesta_de_id` int(11) DEFAULT NULL,
  `mostrar_destinatarios` tinyint(1) NOT NULL DEFAULT 1,
  `version_logica` int(11) NOT NULL DEFAULT 3,
  PRIMARY KEY (`id`),
  KEY `index_mensajes_on_asunto` (`asunto`),
  KEY `index_mensajes_on_autor_id` (`autor_id`),
  KEY `index_mensajes_on_created_at_mensaje_id` (`created_at`,`mensaje_id`),
  KEY `index_mensajes_on_mensaje_id` (`mensaje_id`),
  KEY `index_mensajes_on_respuesta_de_id` (`respuesta_de_id`),
  KEY `index_mensajes_on_updated_at` (`updated_at`),
  FULLTEXT KEY `full` (`asunto`,`cuerpo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `menus_diarios`
--

DROP TABLE IF EXISTS `menus_diarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `menus_diarios` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `autor_id` bigint(20) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `observaciones` text DEFAULT NULL,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `tipo_id` int(11) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `index_menus_diarios_on_autor_id` (`autor_id`),
  KEY `index_horarios_laborales_on_discontinued_at` (`discontinued_at`),
  KEY `index_horarios_laborales_on_position` (`position`),
  KEY `index_menus_diarios_on_tienda_id` (`tienda_id`),
  KEY `idx_menus_diarios_tienda_fecha_tipo` (`tienda_id`,`fecha`,`tipo_id`)
) ENGINE=InnoDB AUTO_INCREMENT=7117 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `menus_diarios_productos`
--

DROP TABLE IF EXISTS `menus_diarios_productos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `menus_diarios_productos` (
  `menu_diario_id` int(11) DEFAULT NULL,
  `producto_id` int(11) DEFAULT NULL,
  KEY `index_menus_diarios_productos_on_menu_diario_id` (`menu_diario_id`),
  KEY `index_menus_diarios_productos_on_producto_id` (`producto_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `metricas_errors`
--

DROP TABLE IF EXISTS `metricas_errors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `metricas_errors` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `fecha` datetime NOT NULL,
  `error_class` varchar(255) DEFAULT NULL,
  `error_message` text DEFAULT NULL,
  `controller_action` varchar(255) DEFAULT NULL,
  `status_code` int(11) DEFAULT NULL,
  `ip` varchar(255) DEFAULT NULL,
  `url` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_metricas_errors_on_fecha` (`fecha`),
  KEY `index_metricas_errors_on_error_class` (`error_class`)
) ENGINE=InnoDB AUTO_INCREMENT=14971 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `metricas_snapshots`
--

DROP TABLE IF EXISTS `metricas_snapshots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `metricas_snapshots` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `fecha` date NOT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `total_requests` int(11) DEFAULT 0,
  `requests_mobile` int(11) DEFAULT 0,
  `requests_desktop` int(11) DEFAULT 0,
  `requests_unknown` int(11) DEFAULT 0,
  `avg_response_time_ms` decimal(8,2) DEFAULT 0.00,
  `p95_response_time_ms` decimal(8,2) DEFAULT 0.00,
  `max_response_time_ms` decimal(8,2) DEFAULT 0.00,
  `status_2xx` int(11) DEFAULT 0,
  `status_3xx` int(11) DEFAULT 0,
  `status_4xx` int(11) DEFAULT 0,
  `status_5xx` int(11) DEFAULT 0,
  `unique_ips` int(11) DEFAULT 0,
  `top_endpoints` text DEFAULT NULL,
  `top_ips` text DEFAULT NULL,
  `response_times_histogram` text DEFAULT NULL,
  `worst_response_times` text DEFAULT NULL,
  `delayed_jobs_stats` text DEFAULT NULL,
  `requests_by_hour` text DEFAULT NULL,
  `db_total_size_mb` decimal(10,2) DEFAULT 0.00,
  `db_table_sizes` text DEFAULT NULL,
  `db_active_connections` int(11) DEFAULT 0,
  `db_max_connections` int(11) DEFAULT 0,
  `db_slow_queries` text DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_metricas_fecha_tienda` (`fecha`,`tienda_id`),
  KEY `index_metricas_snapshots_on_tienda_id` (`tienda_id`)
) ENGINE=InnoDB AUTO_INCREMENT=669 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `movimientos_cbles`
--

DROP TABLE IF EXISTS `movimientos_cbles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `movimientos_cbles` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cuenta_id` int(11) DEFAULT NULL,
  `comprobante_id` int(11) DEFAULT NULL,
  `imputado_id` int(11) DEFAULT NULL,
  `afectacion_id` int(11) DEFAULT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT 0.00,
  `saldo` decimal(12,2) NOT NULL DEFAULT 0.00,
  `created_at` datetime DEFAULT NULL,
  `indice` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_movimientos_on_afectacion_id` (`afectacion_id`) USING BTREE,
  KEY `index_movimientos_on_comprobante_id` (`comprobante_id`) USING BTREE,
  KEY `index_movimientos_on_cuenta_id` (`cuenta_id`) USING BTREE,
  KEY `index_movimientos_on_imputado_id` (`imputado_id`) USING BTREE,
  KEY `index_movimientos_cbles_on_indice` (`indice`) USING BTREE,
  KEY `index_movimientos_cbles_on_saldo` (`saldo`) USING BTREE,
  KEY `index_movimientos_cbles_on_tienda_id` (`tienda_id`),
  KEY `idx_movimientos_tienda_cuenta_indice` (`tienda_id`,`cuenta_id`,`indice`)
) ENGINE=InnoDB AUTO_INCREMENT=644469 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notificaciones`
--

DROP TABLE IF EXISTS `notificaciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `notificaciones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notificaciones_enviadas`
--

DROP TABLE IF EXISTS `notificaciones_enviadas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `notificaciones_enviadas` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `notificacion_id` int(11) DEFAULT NULL,
  `destinatario_id` int(11) DEFAULT NULL,
  `remitente_id` int(11) DEFAULT NULL,
  `via_id` int(11) NOT NULL DEFAULT 1,
  `mensaje_id` int(11) DEFAULT NULL,
  `leida_el` datetime DEFAULT NULL,
  `favorita` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `ultima` tinyint(1) NOT NULL DEFAULT 0,
  `sin_leer_en_cadena` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_notificaciones_enviadas_unique` (`notificacion_id`,`destinatario_id`,`via_id`),
  KEY `index_notificaciones_enviadas_mensaje_favorito` (`destinatario_id`,`mensaje_id`,`via_id`),
  KEY `index_notificaciones_enviadas_query_panel_favoritos` (`destinatario_id`,`via_id`,`favorita`),
  KEY `index_notificaciones_enviadas_query_panel_no_leidos` (`destinatario_id`,`via_id`,`leida_el`),
  KEY `index_notificaciones_enviadas_query_panel_main` (`destinatario_id`,`via_id`,`ultima`,`created_at`),
  KEY `index_notificaciones_enviadas_on_mensaje_id` (`mensaje_id`),
  KEY `index_notificaciones_enviadas_on_remitente_id` (`remitente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pagos_electronicos`
--

DROP TABLE IF EXISTS `pagos_electronicos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pagos_electronicos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `pedido_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `pago_id` bigint(20) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  `date_last_updated` datetime DEFAULT NULL,
  `money_release_date` datetime DEFAULT NULL,
  `payment_method_id` varchar(255) DEFAULT NULL,
  `payment_type_id` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `status_detail` varchar(255) DEFAULT NULL,
  `currency_id` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `collector_id` bigint(20) DEFAULT NULL,
  `order_id` bigint(20) DEFAULT NULL,
  `installments` int(11) NOT NULL DEFAULT 1,
  `transaction_amount` decimal(12,2) DEFAULT NULL,
  `transaction_amount_refunded` decimal(12,2) DEFAULT NULL,
  `coupon_amount` decimal(12,2) DEFAULT NULL,
  `net_received_amount` decimal(12,2) DEFAULT NULL,
  `total_paid_amount` decimal(12,2) DEFAULT NULL,
  `overpaid_amount` decimal(12,2) DEFAULT NULL,
  `installment_amount` decimal(12,2) DEFAULT NULL,
  `pedido_multiple_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_pagos_electronicos_on_pedido_id` (`pedido_id`),
  KEY `index_pagos_electronicos_on_position` (`position`),
  KEY `index_pagos_electronicos_on_pago_id` (`pago_id`),
  KEY `index_pagos_electronicos_on_pedido_multiple_id` (`pedido_multiple_id`)
) ENGINE=InnoDB AUTO_INCREMENT=31573 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos`
--

DROP TABLE IF EXISTS `pedidos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `autor_id` bigint(20) DEFAULT NULL,
  `usuario_id` bigint(20) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `codigo` int(11) DEFAULT NULL,
  `viendo_categorias_csv` varchar(255) DEFAULT NULL,
  `busqueda` varchar(255) DEFAULT NULL,
  `estado_id` int(11) DEFAULT 1,
  `observaciones_cliente` varchar(255) DEFAULT NULL,
  `observaciones_chef` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `facturado` tinyint(1) DEFAULT 0,
  `envio_a_domicilio` tinyint(1) DEFAULT 0,
  `direccion_envio` varchar(255) DEFAULT NULL,
  `cuenta_id` int(11) DEFAULT NULL,
  `pedido_para_empresa` tinyint(1) DEFAULT 0,
  `para` varchar(255) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `venta_mostrador` tinyint(1) DEFAULT 0,
  `confirmation_token` varchar(26) DEFAULT NULL,
  `cobrado` tinyint(1) DEFAULT 0,
  `horario_id` int(11) DEFAULT NULL,
  `costo_envio_domicilio` decimal(12,2) NOT NULL DEFAULT 0.00,
  `local_id` int(11) DEFAULT NULL,
  `pedido_cocina_id` int(11) DEFAULT NULL,
  `stock_reducido` tinyint(1) NOT NULL DEFAULT 0,
  `turno_entrega_id` bigint(20) DEFAULT NULL,
  `cupon_id` bigint(20) DEFAULT NULL,
  `medio_pago_tipo` varchar(255) DEFAULT NULL,
  `aceptado_el` datetime(6) DEFAULT NULL,
  `aceptado_por_id` int(11) DEFAULT NULL,
  `descuento_venta_mostrador_id` bigint(20) DEFAULT NULL,
  `monto_descuento_vm` decimal(12,2) DEFAULT NULL,
  `pedido_multiple_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_pedidos_on_autor_id` (`autor_id`),
  KEY `index_pedidos_on_usuario_id` (`usuario_id`),
  KEY `index_pedidos_on_estado_id` (`estado_id`) USING BTREE,
  KEY `index_pedidos_on_usuario_id_fecha_and_codigo` (`usuario_id`,`fecha`,`codigo`) USING BTREE,
  KEY `index_pedidos_on_confirmation_token` (`confirmation_token`),
  KEY `index_pedidos_on_horario_id` (`horario_id`),
  KEY `index_pedidos_on_local_id` (`local_id`),
  KEY `index_pedidos_on_stock_reducido` (`stock_reducido`),
  KEY `index_pedidos_on_turno_entrega_id` (`turno_entrega_id`),
  KEY `index_pedidos_on_cuenta_estado_fecha` (`cuenta_id`,`estado_id`,`fecha`),
  KEY `index_pedidos_on_cupon_id` (`cupon_id`),
  KEY `index_pedidos_on_mostrador_lookup` (`tienda_id`,`venta_mostrador`,`estado_id`,`autor_id`),
  KEY `index_pedidos_on_cuenta_para` (`cuenta_id`,`para`),
  KEY `index_pedidos_on_tienda_updated_at` (`tienda_id`,`updated_at`),
  KEY `idx_pedidos_tienda_fecha_codigo` (`tienda_id`,`fecha`,`codigo`),
  KEY `idx_pedidos_tienda_estado_fecha_codigo` (`tienda_id`,`estado_id`,`fecha`,`codigo`),
  KEY `idx_pedidos_tienda_cuenta_fecha_codigo` (`tienda_id`,`cuenta_id`,`fecha`,`codigo`),
  KEY `index_pedidos_on_pedido_cocina_id` (`pedido_cocina_id`),
  KEY `idx_pedidos_tienda_vm_fecha_codigo` (`tienda_id`,`venta_mostrador`,`fecha`,`codigo`),
  KEY `index_pedidos_on_descuento_venta_mostrador_id` (`descuento_venta_mostrador_id`),
  KEY `idx_pedidos_tienda_local_estado_fecha` (`tienda_id`,`local_id`,`estado_id`,`fecha`),
  KEY `index_pedidos_on_pedido_multiple_id` (`pedido_multiple_id`),
  CONSTRAINT `fk_rails_46ad1068d6` FOREIGN KEY (`descuento_venta_mostrador_id`) REFERENCES `descuentos_venta_mostrador` (`id`),
  CONSTRAINT `fk_rails_7ed191f265` FOREIGN KEY (`turno_entrega_id`) REFERENCES `turnos_entrega` (`id`),
  CONSTRAINT `fk_rails_992494f7d9` FOREIGN KEY (`cupon_id`) REFERENCES `cupones` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=674819 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos_cocina`
--

DROP TABLE IF EXISTS `pedidos_cocina`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos_cocina` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `fecha` datetime DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `autor_id` int(11) DEFAULT NULL,
  `codigo` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `associated_index` (`tienda_id`,`fecha`,`updated_at`),
  KEY `index_pedidos_cocina_on_autor_id` (`autor_id`),
  KEY `index_pedidos_cocina_on_tienda_id` (`tienda_id`),
  KEY `index_pedidos_cocina_on_fecha` (`fecha`),
  KEY `index_pedidos_cocina_on_codigo` (`codigo`)
) ENGINE=InnoDB AUTO_INCREMENT=1300 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos_cocina_usuarios`
--

DROP TABLE IF EXISTS `pedidos_cocina_usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos_cocina_usuarios` (
  `pedido_cocina_id` bigint(20) NOT NULL,
  `usuario_id` bigint(20) NOT NULL,
  KEY `index_pedidos_cocina_usuarios_on_pedido_cocina_id` (`pedido_cocina_id`),
  KEY `index_pedidos_cocina_usuarios_on_usuario_id` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos_medios_pago`
--

DROP TABLE IF EXISTS `pedidos_medios_pago`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos_medios_pago` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `pedido_id` bigint(20) NOT NULL,
  `tipo` varchar(255) NOT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT 0.00,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_pedidos_medios_pago_on_pedido_id` (`pedido_id`),
  CONSTRAINT `fk_rails_f1fa234464` FOREIGN KEY (`pedido_id`) REFERENCES `pedidos` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8369 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos_multiples`
--

DROP TABLE IF EXISTS `pedidos_multiples`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos_multiples` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `usuario_id` bigint(20) DEFAULT NULL,
  `estado` int(11) NOT NULL DEFAULT 0,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `cuenta_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_pedidos_multiples_on_usuario_id` (`usuario_id`),
  KEY `index_pedidos_multiples_on_cuenta_id` (`cuenta_id`),
  CONSTRAINT `fk_rails_d2374c71a0` FOREIGN KEY (`cuenta_id`) REFERENCES `cuentas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=121 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `pedidos_productos_solicitados`
--

DROP TABLE IF EXISTS `pedidos_productos_solicitados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `pedidos_productos_solicitados` (
  `pedido_id` int(11) DEFAULT NULL,
  `producto_solicitado_id` int(11) DEFAULT NULL,
  KEY `i_trat_tur_on_pedido_id_and_producto_solicitado_id` (`pedido_id`,`producto_solicitado_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `plantillas`
--

DROP TABLE IF EXISTS `plantillas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `plantillas` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `clase_cbte` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_plantillas_on_clase_cbte` (`clase_cbte`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `precios`
--

DROP TABLE IF EXISTS `precios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `precios` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `producto_id` bigint(20) DEFAULT NULL,
  `fecha_desde` date DEFAULT NULL,
  `fecha_hasta` date DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `importe` decimal(12,2) NOT NULL DEFAULT 0.00,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_precios_on_producto_id` (`producto_id`),
  KEY `index_horarios_laborales_on_discontinued_at` (`discontinued_at`),
  KEY `precios_on_position` (`producto_id`,`position`),
  KEY `index_precios_on_producto_fechas` (`producto_id`,`fecha_desde`,`fecha_hasta`),
  KEY `index_precios_on_fechas_producto` (`fecha_desde`,`fecha_hasta`,`producto_id`)
) ENGINE=InnoDB AUTO_INCREMENT=57970 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `preferencias`
--

DROP TABLE IF EXISTS `preferencias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `preferencias` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `estado` tinyint(1) DEFAULT 0,
  `valor` varchar(255) DEFAULT NULL,
  `usuario_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_preferencias_on_usuario_id_and_nombre` (`usuario_id`,`nombre`),
  KEY `index_preferencias_on_usuario_id` (`usuario_id`)
) ENGINE=InnoDB AUTO_INCREMENT=41615 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `procesos`
--

DROP TABLE IF EXISTS `procesos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `procesos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `desde` date DEFAULT NULL,
  `hasta` date DEFAULT NULL,
  `params` text DEFAULT NULL,
  `run_at` datetime DEFAULT NULL,
  `autor_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `adjunto_file_name` varchar(255) DEFAULT NULL,
  `adjunto_content_type` varchar(255) DEFAULT NULL,
  `adjunto_file_size` varchar(255) DEFAULT NULL,
  `importar` tinyint(1) NOT NULL DEFAULT 0,
  `generado_por_id` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_procesos_on_autor_id` (`autor_id`),
  KEY `index_procesos_on_tienda_id_autor_id` (`tienda_id`,`autor_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=29578 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `productos`
--

DROP TABLE IF EXISTS `productos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `productos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `categoria_id` bigint(20) DEFAULT NULL,
  `nombre` varchar(255) DEFAULT NULL,
  `codigo` varchar(255) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `color` varchar(255) DEFAULT NULL,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `codigos_externos` varchar(255) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  `mostrar_como_nuevo_hasta` date DEFAULT NULL,
  `pesable` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `index_productos_on_categoria_id` (`categoria_id`),
  KEY `index_productos_on_codigo` (`nombre`),
  KEY `index_productos_on_nombre` (`codigo`),
  KEY `index_productos_on_categoria_id_and_nombre` (`categoria_id`,`nombre`),
  KEY `index_productos_on_discontinued_at` (`discontinued_at`),
  KEY `index_productos_on_tienda_id` (`tienda_id`),
  KEY `index_productos_on_tienda_codigos_externos` (`tienda_id`,`codigos_externos`),
  KEY `index_productos_on_tienda_discontinued_pesable_categoria` (`tienda_id`,`discontinued_at`,`pesable`,`categoria_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6636 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `productos_solicitados`
--

DROP TABLE IF EXISTS `productos_solicitados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `productos_solicitados` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `pedido_id` bigint(20) DEFAULT NULL,
  `producto_id` bigint(20) DEFAULT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 0,
  `precio_unitario` decimal(12,2) NOT NULL DEFAULT 0.00,
  `observaciones_cliente` text DEFAULT NULL,
  `observaciones_chef` text DEFAULT NULL,
  `realizado` tinyint(1) NOT NULL DEFAULT 0,
  `menu_diario_id` int(11) DEFAULT NULL,
  `pesable` tinyint(1) DEFAULT 0,
  `precio_con_descuento` decimal(12,2) DEFAULT NULL,
  `peso` decimal(10,3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_productos_solicitados_on_producto_id` (`producto_id`),
  KEY `index_productos_solicitados_on_menu_diario_id` (`menu_diario_id`),
  KEY `index_prod_solicitados_on_pedido_producto` (`pedido_id`,`producto_id`),
  KEY `index_productos_solicitados_on_pedido_id` (`pedido_id`),
  KEY `idx_prod_solicitados_pedido_menu_producto` (`pedido_id`,`menu_diario_id`,`producto_id`)
) ENGINE=InnoDB AUTO_INCREMENT=834245 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `productos_stock_movimientos`
--

DROP TABLE IF EXISTS `productos_stock_movimientos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `productos_stock_movimientos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `stock_id` bigint(20) NOT NULL,
  `usuario_id` bigint(20) DEFAULT NULL,
  `tipo` varchar(255) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `cantidad_anterior` int(11) NOT NULL,
  `cantidad_nueva` int(11) NOT NULL,
  `motivo` text DEFAULT NULL,
  `observaciones` text DEFAULT NULL,
  `fecha` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_productos_stock_movimientos_on_stock_id` (`stock_id`),
  KEY `index_productos_stock_movimientos_on_usuario_id` (`usuario_id`),
  KEY `index_stock_movimientos_stock` (`stock_id`),
  KEY `index_stock_movimientos_tipo` (`tipo`),
  KEY `index_stock_movimientos_fecha` (`fecha`),
  KEY `index_stock_movimientos_stock_fecha` (`stock_id`,`fecha`),
  KEY `index_stock_movimientos_tipo_fecha` (`tipo`,`fecha`),
  CONSTRAINT `fk_rails_1a44dacc69` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `fk_rails_e873888f87` FOREIGN KEY (`stock_id`) REFERENCES `productos_stocks` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1419 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `productos_stocks`
--

DROP TABLE IF EXISTS `productos_stocks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `productos_stocks` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `producto_id` bigint(20) NOT NULL,
  `tienda_id` bigint(20) NOT NULL,
  `local_id` bigint(20) DEFAULT NULL,
  `cantidad_actual` int(11) NOT NULL DEFAULT 0,
  `cantidad_minima` int(11) NOT NULL DEFAULT 0,
  `cantidad_maxima` int(11) DEFAULT NULL,
  `observaciones` text DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_stocks_producto_tienda_local` (`producto_id`,`tienda_id`,`local_id`),
  KEY `index_productos_stocks_on_producto_id` (`producto_id`),
  KEY `index_productos_stocks_on_tienda_id` (`tienda_id`),
  KEY `index_productos_stocks_on_local_id` (`local_id`),
  KEY `index_stocks_tienda_local` (`tienda_id`,`local_id`),
  KEY `index_stocks_cantidad_actual` (`cantidad_actual`),
  KEY `index_stocks_cantidad_comparison` (`cantidad_actual`,`cantidad_minima`),
  CONSTRAINT `fk_rails_37c1d17fac` FOREIGN KEY (`local_id`) REFERENCES `locales` (`id`),
  CONSTRAINT `fk_rails_6104c1f480` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`),
  CONSTRAINT `fk_rails_9970af0b17` FOREIGN KEY (`producto_id`) REFERENCES `productos` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6118 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `progresos`
--

DROP TABLE IF EXISTS `progresos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `progresos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `progresable_id` int(11) DEFAULT NULL,
  `progresable_type` varchar(255) DEFAULT NULL,
  `actual` int(11) NOT NULL DEFAULT 0,
  `total` int(11) NOT NULL DEFAULT 0,
  `fecha_inicio` datetime DEFAULT NULL,
  `fecha_fin` datetime DEFAULT NULL,
  `errores` text DEFAULT NULL,
  `cancelado` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=29578 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `provincias`
--

DROP TABLE IF EXISTS `provincias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `provincias` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `codigo` int(11) DEFAULT NULL,
  `nombre` varchar(20) DEFAULT NULL,
  `letra` varchar(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `questiones`
--

DROP TABLE IF EXISTS `questiones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `questiones` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `survey_id` bigint(20) DEFAULT NULL,
  `text` text DEFAULT NULL,
  `question_type` varchar(255) DEFAULT NULL,
  `required` tinyint(1) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_questiones_on_survey_id` (`survey_id`),
  CONSTRAINT `fk_rails_a5ec678892` FOREIGN KEY (`survey_id`) REFERENCES `surveys` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `questiones_responses`
--

DROP TABLE IF EXISTS `questiones_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `questiones_responses` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `survey_response_id` bigint(20) DEFAULT NULL,
  `question_id` bigint(20) DEFAULT NULL,
  `answer_id` bigint(20) DEFAULT NULL,
  `response_text` text DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_questiones_responses_on_survey_response_id` (`survey_response_id`),
  KEY `index_questiones_responses_on_question_id` (`question_id`),
  KEY `index_questiones_responses_on_answer_id` (`answer_id`),
  CONSTRAINT `fk_rails_3c62f2d971` FOREIGN KEY (`answer_id`) REFERENCES `answeres` (`id`),
  CONSTRAINT `fk_rails_5c245684fd` FOREIGN KEY (`question_id`) REFERENCES `questiones` (`id`),
  CONSTRAINT `fk_rails_9644ba2479` FOREIGN KEY (`survey_response_id`) REFERENCES `survey_responses` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1396 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `recordatorios`
--

DROP TABLE IF EXISTS `recordatorios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `recordatorios` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mensaje_id` int(11) DEFAULT NULL,
  `destinatario_id` int(11) DEFAULT NULL,
  `autor_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `recordar_el` datetime DEFAULT NULL,
  `duracion` int(11) NOT NULL DEFAULT 2,
  PRIMARY KEY (`id`),
  KEY `index_recordatorios_on_recordar_el` (`recordar_el`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `registration_tokens`
--

DROP TABLE IF EXISTS `registration_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `registration_tokens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `usuario_id` bigint(20) DEFAULT NULL,
  `token` varchar(255) DEFAULT NULL,
  `platform` varchar(20) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_registration_tokens_on_token` (`token`),
  KEY `index_registration_tokens_on_usuario_id_and_token` (`usuario_id`,`token`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `renglones`
--

DROP TABLE IF EXISTS `renglones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `renglones` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `comprobante_id` bigint(20) DEFAULT NULL,
  `tasa_iva_id` int(11) NOT NULL DEFAULT 1,
  `producto_id` bigint(20) DEFAULT NULL,
  `descripcion` varchar(500) DEFAULT NULL,
  `cantidad` int(11) NOT NULL DEFAULT 1,
  `precio_unitario` decimal(12,2) NOT NULL DEFAULT 0.00,
  `comprobante_afectado_id` bigint(20) DEFAULT NULL,
  `categoria_id` bigint(20) DEFAULT NULL,
  `peso` decimal(10,3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_renglones_on_comprobante_id` (`comprobante_id`),
  KEY `index_renglones_on_producto_id` (`producto_id`),
  KEY `index_renglones_on_comprobante_afectado_id` (`comprobante_afectado_id`),
  KEY `index_renglones_on_categoria_id` (`categoria_id`)
) ENGINE=InnoDB AUTO_INCREMENT=809669 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `titulo` varchar(255) DEFAULT NULL,
  `modulo` varchar(255) DEFAULT NULL,
  `sugerido` tinyint(1) NOT NULL DEFAULT 0,
  `transitivos` text DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_roles_on_modulo` (`modulo`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles_asignados`
--

DROP TABLE IF EXISTS `roles_asignados`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles_asignados` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `usuario_id` int(11) NOT NULL,
  `rol_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_roles_asignados_on_usuario_id_and_rol_id` (`usuario_id`,`rol_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8108 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `session_id` varchar(255) NOT NULL,
  `data` text DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_sessions_on_session_id` (`session_id`),
  KEY `index_sessions_on_updated_at` (`updated_at`),
  KEY `index_sessions_on_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=834647 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subtotales`
--

DROP TABLE IF EXISTS `subtotales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `subtotales` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `comprobante_id` int(11) DEFAULT NULL,
  `tasa_iva_id` int(11) DEFAULT NULL,
  `base_imponible` decimal(12,2) NOT NULL DEFAULT 0.00,
  `iva` decimal(12,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_subtotales_on_comprobante_id_and_tasa_iva_id` (`comprobante_id`,`tasa_iva_id`) USING BTREE,
  KEY `index_subtotales_on_comprobante_id` (`comprobante_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1060273 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `survey_responses`
--

DROP TABLE IF EXISTS `survey_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `survey_responses` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `survey_id` bigint(20) DEFAULT NULL,
  `user_id` bigint(20) DEFAULT NULL,
  `tienda_id` bigint(20) NOT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_survey_responses_on_survey_id` (`survey_id`),
  KEY `index_survey_responses_on_user_id` (`user_id`),
  KEY `index_survey_responses_on_tienda_id` (`tienda_id`),
  CONSTRAINT `fk_rails_51339c6770` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`),
  CONSTRAINT `fk_rails_b0f344463a` FOREIGN KEY (`user_id`) REFERENCES `usuarios` (`id`),
  CONSTRAINT `fk_rails_ec71731d4b` FOREIGN KEY (`survey_id`) REFERENCES `surveys` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=234 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `surveys`
--

DROP TABLE IF EXISTS `surveys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `surveys` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `active` tinyint(1) DEFAULT NULL,
  `tienda_id` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `fecha_desde` date DEFAULT NULL,
  `fecha_hasta` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_surveys_on_tienda_id` (`tienda_id`),
  CONSTRAINT `fk_rails_60754de897` FOREIGN KEY (`tienda_id`) REFERENCES `tiendas` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `suscripciones`
--

DROP TABLE IF EXISTS `suscripciones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `suscripciones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `usuario_id` int(11) DEFAULT NULL,
  `tipo_id` int(11) DEFAULT NULL,
  `vias_ids` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_suscripciones_on_usuario_id_and_tipo_id` (`usuario_id`,`tipo_id`),
  KEY `index_suscripciones_on_tipo_id` (`tipo_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `taggings`
--

DROP TABLE IF EXISTS `taggings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `taggings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tag_id` int(11) DEFAULT NULL,
  `taggable_id` int(11) DEFAULT NULL,
  `tagger_id` int(11) DEFAULT NULL,
  `tagger_type` varchar(255) DEFAULT NULL,
  `taggable_type` varchar(255) DEFAULT NULL,
  `context` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_taggings_on_tag_id` (`tag_id`),
  KEY `index_taggings_on_taggable_id_and_taggable_type_and_context` (`taggable_id`,`taggable_type`,`context`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `taggings_count` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tiendas`
--

DROP TABLE IF EXISTS `tiendas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `tiendas` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `color_de_fondo` varchar(255) DEFAULT NULL,
  `color_de_menu` varchar(255) DEFAULT NULL,
  `color_barra_superior` varchar(255) DEFAULT NULL,
  `color_fondo_logo` varchar(255) DEFAULT NULL,
  `color_barra_filtros` varchar(255) DEFAULT NULL,
  `color_links_hover` varchar(255) DEFAULT NULL,
  `color_links` varchar(255) DEFAULT NULL,
  `color_titulo` varchar(255) DEFAULT NULL,
  `dominio` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `telefono` varchar(255) DEFAULT NULL,
  `domicilio` varchar(255) DEFAULT NULL,
  `video_ayuda` varchar(255) DEFAULT NULL,
  `discontinued_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `venta_mostrador` tinyint(1) DEFAULT 0,
  `carrito_de_compras` tinyint(1) DEFAULT 0,
  `despachos` tinyint(1) DEFAULT 0,
  `mensaje_bienvenida` text DEFAULT NULL,
  `mensaje_ingreso_a_carrito` varchar(255) DEFAULT NULL,
  `horarios_de_entrega` tinyint(1) DEFAULT 0,
  `costo_envio_domicilio` decimal(12,2) NOT NULL DEFAULT 0.00,
  `multiple_locales` tinyint(1) DEFAULT 0,
  `impresion_productos` tinyint(1) DEFAULT 0,
  `stock_notifications_email` varchar(255) DEFAULT NULL,
  `maneja_stock` tinyint(1) NOT NULL DEFAULT 0,
  `dark_mode_login` tinyint(1) NOT NULL DEFAULT 0,
  `productos_pesables` tinyint(1) NOT NULL DEFAULT 0,
  `local_atencion_carrito_id` bigint(20) DEFAULT NULL,
  `soporta_productos_diarios` tinyint(1) NOT NULL DEFAULT 0,
  `muestra_mas_productos` tinyint(1) NOT NULL DEFAULT 0,
  `muestra_menus_del_dia` tinyint(1) NOT NULL DEFAULT 0,
  `permitir_login_clientes` tinyint(1) NOT NULL DEFAULT 1,
  `muestra_mas_productos_por_categoria` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `index_tiendas_on_discontinued_at` (`discontinued_at`),
  KEY `index_tiendas_on_dominio` (`dominio`),
  KEY `index_tiendas_on_local_atencion_carrito_id` (`local_atencion_carrito_id`),
  CONSTRAINT `fk_rails_e11206b005` FOREIGN KEY (`local_atencion_carrito_id`) REFERENCES `locales` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tipos_comprobantes`
--

DROP TABLE IF EXISTS `tipos_comprobantes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `tipos_comprobantes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `desc` varchar(255) DEFAULT NULL,
  `clase` varchar(50) DEFAULT NULL,
  `letra` varchar(1) DEFAULT NULL,
  `codigo` int(11) DEFAULT NULL,
  `debitan` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `index_tipos_comprobantes_on_codigo` (`codigo`) USING BTREE,
  KEY `index_tipos_comprobantes_on_letra_and_clase` (`letra`,`clase`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `turnos_entrega`
--

DROP TABLE IF EXISTS `turnos_entrega`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `turnos_entrega` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(255) NOT NULL,
  `codigo` varchar(255) NOT NULL,
  `hora_corte` time NOT NULL,
  `descripcion` text DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  `posicion` int(11) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_turnos_entrega_on_codigo` (`codigo`),
  KEY `index_turnos_entrega_on_activo` (`activo`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `turnos_entrega_categorias`
--

DROP TABLE IF EXISTS `turnos_entrega_categorias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `turnos_entrega_categorias` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `turno_entrega_id` bigint(20) NOT NULL,
  `categoria_id` bigint(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_turnos_categorias_on_turno_and_categoria` (`turno_entrega_id`,`categoria_id`),
  KEY `index_turnos_entrega_categorias_on_turno_entrega_id` (`turno_entrega_id`),
  KEY `index_turnos_entrega_categorias_on_categoria_id` (`categoria_id`),
  CONSTRAINT `fk_rails_6c9167c84b` FOREIGN KEY (`turno_entrega_id`) REFERENCES `turnos_entrega` (`id`),
  CONSTRAINT `fk_rails_fd7e42c8b7` FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `login` varchar(255) DEFAULT NULL,
  `crypted_password` varchar(40) DEFAULT NULL,
  `salt` varchar(40) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `cuenta_id` bigint(20) DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `remember_token` varchar(255) DEFAULT NULL,
  `remember_token_expires_at` datetime DEFAULT NULL,
  `nombre` varchar(255) DEFAULT NULL,
  `telefono` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password_expires_at` datetime DEFAULT '2036-01-01 00:00:00',
  `notificaciones_sin_leer` int(11) NOT NULL DEFAULT 0,
  `recordatorios_activos` tinyint(1) NOT NULL DEFAULT 0,
  `alertar_notificaciones` tinyint(1) NOT NULL DEFAULT 0,
  `discontinued_at` datetime DEFAULT NULL,
  `dni` int(11) DEFAULT NULL,
  `legajo` varchar(255) DEFAULT NULL,
  `cuit` varchar(255) DEFAULT NULL,
  `direccion_envio` varchar(255) DEFAULT NULL,
  `sucursal` varchar(255) DEFAULT NULL,
  `tipo_usuario_id` int(11) DEFAULT NULL,
  `tienda_cliente_id` int(11) DEFAULT NULL,
  `visualizando_tienda_id` int(11) DEFAULT NULL,
  `local_id` int(11) DEFAULT NULL,
  `visualizando_local_id` bigint(20) DEFAULT NULL,
  `servicio_de_impresion_id` int(11) NOT NULL DEFAULT 1,
  `vista_productos` varchar(255) NOT NULL DEFAULT 'lista',
  PRIMARY KEY (`id`),
  KEY `index_usuarios_on_cuenta_id` (`cuenta_id`),
  KEY `index_usuarios_on_discontinued_at` (`discontinued_at`),
  KEY `index_usuarios_on_login` (`login`),
  KEY `index_usuarios_on_dni` (`dni`),
  KEY `index_usuarios_on_cuenta_id_and_dni` (`cuenta_id`,`dni`),
  KEY `index_usuarios_on_legajo` (`legajo`),
  KEY `index_usuarios_on_cuenta_id_and_legajo` (`cuenta_id`,`legajo`),
  KEY `index_usuarios_on_cuenta_id_and_nombre` (`cuenta_id`,`nombre`),
  KEY `index_usuarios_on_cuenta_id_and_login` (`cuenta_id`,`login`),
  KEY `index_usuarios_on_cuit` (`cuit`),
  KEY `index_usuarios_on_tienda_cliente_id` (`tienda_cliente_id`),
  KEY `index_usuarios_on_visualizando_tienda_id` (`visualizando_tienda_id`),
  KEY `index_usuarios_on_local_id` (`local_id`),
  KEY `index_usuarios_on_visualizando_local_id` (`visualizando_local_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9768 DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `usuarios_tiendas`
--

DROP TABLE IF EXISTS `usuarios_tiendas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios_tiendas` (
  `usuario_id` int(11) DEFAULT NULL,
  `tienda_id` int(11) DEFAULT NULL,
  KEY `index_usuarios_tiendas_on_tienda_id` (`tienda_id`),
  KEY `index_usuarios_tiendas_on_usuario_id` (`usuario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-05-28  0:20:20
