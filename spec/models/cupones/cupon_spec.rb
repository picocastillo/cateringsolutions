require 'rails_helper'

RSpec.describe Cupones::Cupon, type: :model do
  let(:tienda) { create(:tienda) }
  let(:cupon) { create(:cupon, tienda: tienda) }

  describe 'associations' do
    it { is_expected.to belong_to(:tienda).class_name('Tiendas::Tienda') }
    it { is_expected.to have_one(:pedido).class_name('Pedidos::Pedido') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:tipo_descuento) }

    it 'validates inclusion of tipo_descuento' do
      cupon = build(:cupon, tienda: tienda, tipo_descuento: 'invalido')
      expect(cupon).not_to be_valid
      expect(cupon.errors[:tipo_descuento]).to be_present
    end

    context 'when tipo_descuento is importe' do
      it 'requires importe' do
        cupon = build(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: nil)
        expect(cupon).not_to be_valid
        expect(cupon.errors[:importe]).to be_present
      end

      it 'requires positive importe' do
        cupon = build(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: -10)
        expect(cupon).not_to be_valid
      end
    end

    context 'when tipo_descuento is porcentaje' do
      it 'requires porcentaje' do
        cupon = build(:cupon, :porcentaje, tienda: tienda, porcentaje: nil)
        expect(cupon).not_to be_valid
        expect(cupon.errors[:porcentaje]).to be_present
      end

      it 'requires limite_bonificacion' do
        cupon = build(:cupon, :porcentaje, tienda: tienda, limite_bonificacion: nil)
        expect(cupon).not_to be_valid
        expect(cupon.errors[:limite_bonificacion]).to be_present
      end

      it 'validates porcentaje is between 0 and 100' do
        cupon = build(:cupon, :porcentaje, tienda: tienda, porcentaje: 150)
        expect(cupon).not_to be_valid
      end
    end
  end

  describe 'callbacks' do
    it 'generates a random codigo on create' do
      cupon = create(:cupon, tienda: tienda, codigo: nil)
      expect(cupon.codigo).to be_present
      expect(cupon.codigo.length).to eq(8)
    end

    it 'does not overwrite manually set codigo' do
      cupon = create(:cupon, tienda: tienda, codigo: 'MICODIGO')
      expect(cupon.codigo).to eq('MICODIGO')
    end

    it 'sets fecha_vencimiento to 3 months if not provided' do
      cupon = create(:cupon, tienda: tienda, fecha_vencimiento: nil)
      expect(cupon.fecha_vencimiento).to eq(Date.current + 3.months)
    end

    it 'corrects invalid (past) fecha_vencimiento on save' do
      cupon = create(:cupon, tienda: tienda, fecha_vencimiento: Date.current + 1.month)
      cupon.update_column(:fecha_vencimiento, Date.current - 1.week)
      cupon.save!
      expect(cupon.reload.fecha_vencimiento).to eq(Date.current + 3.months)
    end

    it 'preserves valid fecha_vencimiento' do
      future_date = Date.current + 6.months
      cupon = create(:cupon, tienda: tienda, fecha_vencimiento: future_date)
      expect(cupon.fecha_vencimiento).to eq(future_date)
    end
  end

  describe '#to_s' do
    it 'returns the codigo' do
      expect(cupon.to_s).to eq(cupon.codigo)
    end
  end

  describe '#vencido?' do
    it 'returns true when fecha_vencimiento is in the past' do
      cupon = create(:cupon, tienda: tienda)
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect(cupon.vencido?).to be true
    end

    it 'returns false when fecha_vencimiento is in the future' do
      expect(cupon.vencido?).to be false
    end

    it 'returns false when cancelado' do
      cupon = create(:cupon, tienda: tienda)
      cupon.update_columns(fecha_vencimiento: Date.current - 1.day, cancelado: true)
      expect(cupon.vencido?).to be false
    end

    it 'returns false when used by pedido' do
      cupon = create(:cupon, tienda: tienda)
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      create(:pedido, cupon: cupon)
      expect(cupon.vencido?).to be false
    end
  end

  describe '#vigente?' do
    it 'returns true when not used and not vencido' do
      expect(cupon.vigente?).to be true
    end

    it 'returns false when used by pedido' do
      create(:pedido, cupon: cupon)
      expect(cupon.vigente?).to be false
    end

    it 'returns false when vencido' do
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect(cupon.vigente?).to be false
    end
  end

  describe '#descuento_descripcion' do
    it 'returns importe format for importe tipo' do
      cupon = create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 500)
      expect(cupon.descuento_descripcion).to eq('$500')
    end

    it 'returns porcentaje format for porcentaje tipo' do
      cupon = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 10, limite_bonificacion: 1000)
      expect(cupon.descuento_descripcion).to eq('10% (máx $1000)')
    end
  end

  describe 'uniqueness of codigo' do
    it 'does not allow duplicate codigos' do
      create(:cupon, tienda: tienda, codigo: 'UNIQUECD')
      duplicate = build(:cupon, tienda: tienda, codigo: 'UNIQUECD')
      expect(duplicate).not_to be_valid
    end
  end

  describe '.del_grupo' do
    it 'returns cupones with matching grupo' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)
      _other = create(:cupon, tienda: tienda, grupo: SecureRandom.uuid)

      result = described_class.del_grupo(grupo)
      expect(result).to contain_exactly(c1, c2)
    end
  end

  describe '.expirar_grupo!' do
    it 'sets fecha_vencimiento to yesterday for all cupones in the grupo' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)

      described_class.expirar_grupo!(grupo)

      expect(c1.reload.fecha_vencimiento).to eq(Date.current - 1.day)
      expect(c2.reload.fecha_vencimiento).to eq(Date.current - 1.day)
    end
  end

  describe '.eliminar_grupo! (basic)' do
    it 'destroys non-used cupones in the grupo' do
      grupo = SecureRandom.uuid
      create(:cupon, tienda: tienda, grupo: grupo)
      create(:cupon, tienda: tienda, grupo: grupo)
      other = create(:cupon, tienda: tienda, grupo: SecureRandom.uuid)

      described_class.eliminar_grupo!(grupo)

      expect(described_class.del_grupo(grupo).count).to eq(0)
      expect(other.reload).to be_present
    end
  end

  describe '.crear_cantidad' do
    it 'creates the specified number of generic cupones with shared grupo' do
      attrs = { tienda: tienda, tipo_descuento: 'importe', importe: 200 }
      cupones = described_class.crear_cantidad(3, attrs)

      expect(cupones.size).to eq(3)
      expect(cupones.map(&:grupo).uniq.size).to eq(1)
    end
  end

  describe '#estado_texto' do
    it 'returns Cancelado when cancelado' do
      cupon = create(:cupon, :cancelado, tienda: tienda)
      expect(cupon.estado_texto).to eq('Cancelado')
    end

    it 'returns Usado when used by pedido' do
      cupon = create(:cupon, tienda: tienda)
      create(:pedido, cupon: cupon)
      expect(cupon.estado_texto).to eq('Usado')
    end

    it 'returns Vencido when vencido' do
      cupon = create(:cupon, tienda: tienda)
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect(cupon.estado_texto).to eq('Vencido')
    end

    it 'returns Vigente otherwise' do
      expect(cupon.estado_texto).to eq('Vigente')
    end

    it 'prioritizes Cancelado over Vencido' do
      cupon = create(:cupon, tienda: tienda)
      cupon.update_columns(cancelado: true, fecha_vencimiento: Date.current - 1.day)
      expect(cupon.estado_texto).to eq('Cancelado')
    end
  end

  describe '#cancelar!' do
    it 'sets cancelado to true for vigente cupones' do
      cupon.cancelar!
      expect(cupon.reload.cancelado?).to be true
    end

    it 'raises error for used cupones' do
      create(:pedido, cupon: cupon)
      expect { cupon.cancelar! }.to raise_error(RuntimeError, /vigentes/)
    end

    it 'raises error for already cancelado cupones' do
      cupon.update_column(:cancelado, true)
      expect { cupon.cancelar! }.to raise_error(RuntimeError, /vigentes/)
    end

    it 'raises error for vencido cupones' do
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect { cupon.cancelar! }.to raise_error(RuntimeError, /vigentes/)
    end
  end

  describe '#usar!' do
    let(:cliente) { create(:cliente, tienda: tienda) }
    let(:cuenta) { create(:cuenta, cliente: cliente) }
    let(:usuario) { create(:usuario, :admin, cuenta: cuenta, visualizando_tienda: tienda, tienda_cliente: tienda) }
    let(:pedido) { create(:pedido, tienda: tienda, cuenta: cuenta, usuario: usuario, autor: usuario) }

    it 'links cupon to pedido and marks as usado' do
      cupon.usar!(pedido)
      expect(pedido.reload.cupon).to eq(cupon)
      expect(cupon.usado?).to be true
    end

    it 'raises error if cupon is already used' do
      create(:pedido, cupon: cupon)
      expect { cupon.usar!(pedido) }.to raise_error(RuntimeError, /vigentes/)
    end
  end

  describe '#descuento_para' do
    it 'returns importe when less than total' do
      cupon = create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 200)
      expect(cupon.descuento_para(1000)).to eq(200)
    end

    it 'caps at total when importe exceeds total' do
      cupon = create(:cupon, tienda: tienda, tipo_descuento: 'importe', importe: 500)
      expect(cupon.descuento_para(300)).to eq(300)
    end

    it 'calculates porcentaje discount' do
      cupon = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 10, limite_bonificacion: 1000)
      expect(cupon.descuento_para(500)).to eq(50.0)
    end

    it 'caps porcentaje at limite_bonificacion' do
      cupon = create(:cupon, :porcentaje, tienda: tienda, porcentaje: 50, limite_bonificacion: 100)
      expect(cupon.descuento_para(1000)).to eq(100)
    end
  end

  describe '.buscar_vigente' do
    it 'finds a vigente cupon by codigo and tienda' do
      result = described_class.buscar_vigente(cupon.codigo, tienda)
      expect(result).to eq(cupon)
    end

    it 'is case insensitive (upcases input)' do
      result = described_class.buscar_vigente(cupon.codigo.downcase, tienda)
      expect(result).to eq(cupon)
    end

    it 'strips whitespace' do
      result = described_class.buscar_vigente("  #{cupon.codigo}  ", tienda)
      expect(result).to eq(cupon)
    end

    it 'returns nil for used cupones' do
      create(:pedido, cupon: cupon)
      expect(described_class.buscar_vigente(cupon.codigo, tienda)).to be_nil
    end

    it 'returns nil for cancelado cupones' do
      cupon.update_column(:cancelado, true)
      expect(described_class.buscar_vigente(cupon.codigo, tienda)).to be_nil
    end

    it 'returns nil for vencido cupones' do
      cupon.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect(described_class.buscar_vigente(cupon.codigo, tienda)).to be_nil
    end

    it 'returns nil for different tienda' do
      other_tienda = create(:tienda)
      expect(described_class.buscar_vigente(cupon.codigo, other_tienda)).to be_nil
    end
  end

  describe '.cancelar_grupo!' do
    it 'cancels all vigente cupones in the grupo' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)

      described_class.cancelar_grupo!(grupo)

      expect(c1.reload.cancelado?).to be true
      expect(c2.reload.cancelado?).to be true
    end

    it 'does not cancel already used cupones' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)
      create(:pedido, cupon: c2)

      described_class.cancelar_grupo!(grupo)

      expect(c1.reload.cancelado?).to be true
      expect(c2.reload.cancelado?).to be false
    end
  end

  describe '.vigentes' do
    it 'excludes used cupones' do
      used = create(:cupon, tienda: tienda)
      create(:pedido, cupon: used)
      expect(described_class.vigentes).not_to include(used)
    end

    it 'excludes cancelado cupones' do
      cancelled = create(:cupon, :cancelado, tienda: tienda)
      expect(described_class.vigentes).not_to include(cancelled)
    end

    it 'excludes vencido cupones' do
      expired = create(:cupon, tienda: tienda)
      expired.update_column(:fecha_vencimiento, Date.current - 1.day)
      expect(described_class.vigentes).not_to include(expired)
    end

    it 'includes vigente cupones' do
      expect(described_class.vigentes).to include(cupon)
    end
  end

  describe '#eliminable?' do
    it 'returns true when cupon has no pedido' do
      expect(cupon.eliminable?).to be true
    end

    it 'returns false when cupon is used by pedido' do
      create(:pedido, cupon: cupon)
      expect(cupon.eliminable?).to be false
    end
  end

  describe 'before_destroy :verificar_no_usado' do
    it 'allows destroying unused cupon' do
      expect { cupon.destroy! }.not_to raise_error
    end

    it 'prevents destroying cupon used by pedido' do
      create(:pedido, cupon: cupon)
      expect(cupon.destroy).to be false
      expect(cupon.errors[:base]).to include('No se puede eliminar un cupón utilizado por un pedido')
    end
  end

  describe '.no_usados' do
    it 'excludes cupones linked to a pedido' do
      used = create(:cupon, tienda: tienda)
      create(:pedido, cupon: used)
      expect(described_class.no_usados).not_to include(used)
    end

    it 'includes cupones without pedido' do
      expect(described_class.no_usados).to include(cupon)
    end
  end

  describe '.eliminar_grupo!' do
    it 'skips cupones linked to a pedido' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)
      create(:pedido, cupon: c2)

      described_class.eliminar_grupo!(grupo)

      expect(described_class.where(id: c1.id)).not_to exist
      expect(c2.reload).to be_present
    end
  end

  describe '.eliminar_masivo' do
    it 'deletes cupones by codigo' do
      target = create(:cupon, tienda: tienda, codigo: 'DELME123')
      other = create(:cupon, tienda: tienda)

      described_class.eliminar_masivo(codigo: 'DELME123')

      expect(described_class.where(id: target.id)).not_to exist
      expect(other.reload).to be_present
    end

    it 'deletes cupones by grupo' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)
      other = create(:cupon, tienda: tienda)

      described_class.eliminar_masivo(grupo: grupo)

      expect(described_class.where(id: [c1.id, c2.id]).count).to eq(0)
      expect(other.reload).to be_present
    end

    it 'skips cupones used by a pedido' do
      grupo = SecureRandom.uuid
      c1 = create(:cupon, tienda: tienda, grupo: grupo)
      c2 = create(:cupon, tienda: tienda, grupo: grupo)
      create(:pedido, cupon: c2)

      described_class.eliminar_masivo(grupo: grupo)

      expect(described_class.where(id: c1.id)).not_to exist
      expect(c2.reload).to be_present
    end

    it 'strips and upcases codigo' do
      target = create(:cupon, tienda: tienda, codigo: 'MYCODE01')

      described_class.eliminar_masivo(codigo: '  mycode01  ')

      expect(described_class.where(id: target.id)).not_to exist
    end
  end
end
