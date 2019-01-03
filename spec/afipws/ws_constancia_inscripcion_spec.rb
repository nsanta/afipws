require 'spec_helper'

describe Afipws::WSConstanciaInscripcion do
  let(:auth) { {token: 't', sign: 's', expiration_time: 12.hours.from_now, cuit_representada: 1} }
  let(:ws) { Afipws::WSConstanciaInscripcion.new(wsaa: Afipws::WSAA.new(cuit: '1')).tap { |wspadron| wspadron.stubs auth: auth } }

  context 'Métodos' do
    it 'dummy' do
      savon.expects(:dummy).returns(fixture('constancia_inscripcion_dummy/success'))
      ws.dummy.should == { appserver: 'OK', dbserver: 'OK', authserver: 'OK' }
    end

    it 'debería devolver un hash con los datos generales y regímenes impositivos' do
      savon.expects(:get_persona).with(message: auth).returns(fixture('constancia_inscripcion_get_persona/success'))
      r = ws.get_persona '20294834487'
      r[:datos_generales].should have_entries estado_clave: 'ACTIVO', fecha_contrato_social: 'Wed, 31 Jul 1996 12:00:00 -0300',
        id_persona: '30123456784', mes_cierre: '6', razon_social: 'LA REGALERIA S A', tipo_clave: 'CUIT',
        tipo_persona: 'JURIDICA'
      r[:datos_generales][:domicilio_fiscal].should have_entries cod_postal: '2300', descripcion_provincia: 'SANTA FE',
        direccion: 'AV SIEMPRE VIVA 123', localidad: 'NUEVA YORK', tipo_domicilio: 'FISCAL'
      r[:datos_regimen_general][:actividad].should have_entries descripcion_actividad: 'VENTA AL POR MENOR DE INSTRUMENTAL MÉDICO Y ODONTOLÓGICO Y ARTÍCULOS ORTOPÉDICOS', id_actividad: '477330', nomenclador: '883', orden: '2', periodo: '201311'
      r[:datos_regimen_general][:impuesto][1].should have_entries descripcion_impuesto: 'IVA', id_impuesto: '30', periodo: '198903'
      r[:datos_regimen_general][:regimen].should have_entries id_impuesto: '208', id_regimen: '159', periodo: '199403'
    end

    it 'debería devolver en un hash errores de la constancia' do
      savon.expects(:get_persona).with(message: auth).returns(fixture('constancia_inscripcion_get_persona/failure'))
      r = ws.get_persona '20294834487'
      r[:error_regimen_general].should have_entries error: 'El contribuyente cuenta con impuestos con baja de oficio por Decreto 1299/98',
        mensaje: 'No cumple con las condiciones para enviar datos del regimen general'
    end
  end

  context 'autenticacion' do
    before { FileUtils.rm_rf Dir.glob('tmp/*ta.dump') }

    it 'debería autenticarse usando el WSAA' do
      ws_constancia = Afipws::WSConstanciaInscripcion.new cuit: '1', cert: 'cert', key: 'key'
      ws_constancia.wsaa.cert.should == 'cert'
      ws_constancia.wsaa.key.should == 'key'
      ws_constancia.wsaa.service.should == 'ws_sr_constancia_inscripcion'
      ws_constancia.wsaa.expects(:login).returns(token: 't', sign: 's')
      savon.expects(:get_persona).with(message: has_path(
        '//token' => 't', '//sign' => 's', '//cuitRepresentada' => '1'
      )).returns(fixture('constancia_inscripcion_get_persona/success'))
      ws_constancia.get_persona '20294834487'
    end
  end

  context 'entorno' do
    it 'debería usar las url para development cuando el env es development' do
      Afipws::Client.expects(:new).with(wsdl: 'https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl')
      Afipws::Client.expects(:new).with(wsdl: 'https://awshomo.afip.gov.ar/sr-padron/webservices/personaServiceA5?WSDL', ssl_version: :TLSv1, soap_version: 1)
      wsci = Afipws::WSConstanciaInscripcion.new env: :development
      wsci.env.should == :development
    end

    it 'debería usar las url para production cuando el env es production' do
      Afipws::Client.expects(:new).with(wsdl: 'https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl')
      Afipws::Client.expects(:new).with(wsdl: 'https://aws.afip.gov.ar/sr-padron/webservices/personaServiceA5?WSDL', ssl_version: :TLSv1, soap_version: 1)
      wsci = Afipws::WSConstanciaInscripcion.new env: 'production'
      wsci.env.should == :production
    end
  end
end