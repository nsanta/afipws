# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Afipws::WSFE do
  let :ws do 
    wsaa = Afipws::WSAA.new 
    wsaa.stubs :login => { :token => 't', :sign => 's', :expiration_time => 12.hours.from_now }
    Afipws::WSFE.new :cuit => '1', :wsaa => wsaa
  end
  
  context "Métodos de negocio" do
    it "dummy" do
      savon.expects('FEDummy').returns(:success)
      ws.dummy.should == { :app_server => "OK", :db_server => "OK", :auth_server => "OK" }
    end

    it "tipos_comprobantes" do
      savon.expects('FEParamGetTiposCbte').returns(:success)
      ws.tipos_comprobantes.should == [
        { :id => 1, :desc => "Factura A", :fch_desde => Date.new(2010,9,17), :fch_hasta => nil }, 
        { :id => 2, :desc => "Nota de Débito A", :fch_desde => Date.new(2010,9,18), :fch_hasta => Date.new(2011,9,18) }]
    end
    
    it "tipos_documentos" do
      savon.expects('FEParamGetTiposDoc').returns(:success)
      ws.tipos_documentos.should == [{ :id => 80, :desc => "CUIT", :fch_desde => Date.new(2008,7,25), :fch_hasta => nil }]
    end
    
    it "tipos_monedas" do
      savon.expects('FEParamGetTiposMonedas').returns(:success)
      ws.tipos_monedas.should == [
        { :id => 'PES', :desc => "Pesos Argentinos", :fch_desde => Date.new(2009,4,3), :fch_hasta => nil }, 
        { :id => '002', :desc => "Dólar Libre EEUU", :fch_desde => Date.new(2009,4,16), :fch_hasta => nil }]
    end
    
    it "tipos_iva" do
      savon.expects('FEParamGetTiposIva').returns(:success)
      ws.tipos_iva.should == [{ :id => 5, :desc => "21%", :fch_desde => Date.new(2009,2,20), :fch_hasta => nil }] 
    end
    
    it "tipos_tributos" do
      savon.expects('FEParamGetTiposTributos').returns(:success)
      ws.tipos_tributos.should == [{ :id => 2, :desc => "Impuestos provinciales", :fch_desde => Date.new(2010,9,17), :fch_hasta => nil }]
    end
    
    it "puntos_venta" do
      savon.expects('FEParamGetPtosVenta').returns(:success)
      ws.puntos_venta.should == [
        { :nro => 1, :emision_tipo => "CAE", :bloqueado => false, :fch_baja => nil },
        { :nro => 2, :emision_tipo => "CAEA", :bloqueado => true, :fch_baja => Date.new(2011,1,31) }
      ]
    end
    
    context "cotizacion" do
      it "cuando la moneda solicitada existe" do
        savon.expects('FEParamGetCotizacion').with(has_path '/MonId' => 'DOL').returns(:dolar)
        ws.cotizacion('DOL').should == 3.976
      end
      
      it "cuando la moneda no existe" do
        savon.expects('FEParamGetCotizacion').with(has_path '/Auth/Token' => 't', '/MonId' => 'PES').returns(:inexistente)
        expect { ws.cotizacion('PES') }.to raise_error Afipws::WSError, /602: Sin Resultados/
      end
    end
    
    it "cant_max_registros_x_lote" do
      savon.expects('FECompTotXRequest').with(has_path '/Auth/Token' => 't').returns(:success)
      ws.cant_max_registros_x_lote.should == 250
    end
    
    context "autorizar_comprobante" do
      it "debería devolver un hash con el CAE y su fecha de vencimiento" do
        savon.expects('FECAESolicitar').with(has_path '/Auth/Token' => 't',
          '/FeCAEReq/FeCabReq/CantReg' => 1,
          '/FeCAEReq/FeCabReq/PtoVta' => 2,
          '/FeCAEReq/FeCabReq/CbteTipo' => 1,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/DocTipo' => 80,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/DocNro' => 30521189203,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/CbteFch' => '20110113',
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/ImpTotal' => 1270.48,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/ImpIVA' => 220.5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[0]/Id' => 5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[0]/Importe' => 220.5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Tributos/Tributo[0]/Id' => 0,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Tributos/Tributo[0]/BaseImp' => 150,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Tributos/Tributo[0]/Alic' => 5.2,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Tributos/Tributo[0]/Importe' => 7.8
        ).returns(:autorizacion_1_cbte)
        rta = ws.autorizar_comprobantes(:cbte_tipo => 1, :pto_vta => 2, :comprobantes => [{:cbte_nro => 1, :concepto => 1, 
          :doc_nro => 30521189203, :doc_tipo => 80, :cbte_fch => Date.new(2011,01,13), 
          :imp_total => 1270.48, :imp_neto => 1049.98, :imp_iva => 220.50, :mon_id => 'PES', :mon_cotiz => 1,
          :iva => { :alic_iva => [{ :id => 5, :base_imp => 1049.98, :importe => 220.50 }]},
          :tributos => { :tributo => [{ :id => 0, :base_imp => 150, :alic => 5.2, :importe => 7.8 }] }
        }])
        rta[0].should have_entries :cae => '61023008595705', :cae_fch_vto => Date.new(2011,01,23), :cbte_nro => 1, 
          :resultado => 'A', :observaciones => []
        rta.should have(1).item
      end

      it "con varias alicuotas iva" do
        savon.expects('FECAESolicitar').with(has_path({
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[0]/Id' => 5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[0]/Importe' => 21,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[1]/Id' => 4,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/Iva/AlicIva[1]/Importe' => 5.25
        })).returns(:autorizacion_1_cbte)
        ws.autorizar_comprobantes(:cbte_tipo => 1, :pto_vta => 2, :comprobantes => [{:iva => {:alic_iva => [
            { :id => 5, :base_imp => 100, :importe => 21 },
            { :id => 4, :base_imp => 50, :importe => 5.25 }
        ]}}])
      end
      
      it "con varios comprobantes aprobados" do
        savon.expects('FECAESolicitar').with(has_path({
          '/FeCAEReq/FeCabReq/CantReg' => 2,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/CbteDesde' => 5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[0]/CbteHasta' => 5,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[1]/CbteDesde' => 6,
          '/FeCAEReq/FeDetReq/FECAEDetRequest[1]/CbteHasta' => 6,
        })).returns(:autorizacion_2_cbtes)
        rta = ws.autorizar_comprobantes(:cbte_tipo => 1, :pto_vta => 2, :comprobantes => [
          { :cbte_nro => 5 }, { :cbte_nro => 6 }
        ])
        rta[0].should have_entries :cbte_nro => 5, :cae => '61033008894096'
        rta[1].should have_entries :cbte_nro => 6, :cae => '61033008894101'
      end
      
      it "con 2 observaciones" do
        savon.stubs('FECAESolicitar').returns(:dos_observaciones)
        rta = ws.autorizar_comprobantes :comprobantes => []
        rta[0].should have_entries :cbte_nro => 3, :cae => nil, :resultado => 'R', :observaciones => [
          {:code => 10048, :msg => 'Msg 1'}, {:code => 10018, :msg => 'Msg 2'}]
      end

      it "con 1 observación" do
        savon.stubs('FECAESolicitar').returns(:una_observacion)
        rta = ws.autorizar_comprobantes :comprobantes => []
        rta[0].should have_entries :observaciones => [{:code => 10048, :msg => 'Msg 1'}]
      end
    end
    
    context "solicitar_caea" do
      it "debería mandar automáticamente el período y orden" do
        Date.stubs :today => Date.new(2011,1,27)
        savon.expects('FECAEASolicitar').with(has_path '/Periodo' => '201102', '/Orden' => 1).returns(:success)
        ws.solicitar_caea.should have_entries :caea => '21043476341977', :fch_tope_inf => Date.new(2011,03,17), 
          :fch_vig_desde => Date.new(2011,02,01), :fch_vig_hasta => Date.new(2011,02,15)
      end
      
      context "periodo_para_solicitud_caea" do
        it "cuando estoy en la primer quincena" do
          Date.stubs :today => Date.new(2011,1,12)
          ws.periodo_para_solicitud_caea.should == { :periodo => '201101', :orden => 2 }
          Date.stubs :today => Date.new(2011,1,15)
          ws.periodo_para_solicitud_caea.should == { :periodo => '201101', :orden => 2 }
        end
        
        it "cuando estoy en la segunda quincena" do
          Date.stubs :today => Date.new(2011,1,16)
          ws.periodo_para_solicitud_caea.should == { :periodo => '201102', :orden => 1 }
          Date.stubs :today => Date.new(2011,1,31)
          ws.periodo_para_solicitud_caea.should == { :periodo => '201102', :orden => 1 }
        end        
      end
      
      it "cuando el caea ya fue otorgado debería consultarlo y devolverlo" do
        Date.stubs :today => Date.new(2011,1,27)
        savon.expects('FECAEASolicitar').with(has_path '/Periodo' => '201102', '/Orden' => 1).returns(:caea_ya_otorgado)
        savon.expects('FECAEAConsultar').with(has_path '/Periodo' => '201102', '/Orden' => 1).returns(:success)
        ws.solicitar_caea.should have_entries :caea => '21043476341977', :fch_vig_desde => Date.new(2011,02,01)
      end    
      
      it "cuando hay otro error debería burbujearlo" do
        savon.expects('FECAEASolicitar').returns(:error_distinto)
        expect { ws.solicitar_caea }.to raise_error Afipws::WSError, /15007/
      end  
    end
    
    it "informar_comprobantes_caea" do
      savon.expects('FECAEARegInformativo').with(has_path({ '/Auth/Token' => 't',
        '/FeCAEARegInfReq/FeCabReq/CantReg' => 2,
        '/FeCAEARegInfReq/FeCabReq/PtoVta' => 3,
        '/FeCAEARegInfReq/FeCabReq/CbteTipo' => 1,
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[0]/CbteDesde' => 1,
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[0]/CbteHasta' => 1,
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[0]/CAEA' => '21043476341977',
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CbteDesde' => 2,
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CbteHasta' => 2,
        '/FeCAEARegInfReq/FeDetReq/FECAEADetRequest[1]/CAEA' => '21043476341977',
      })).returns(:informe_rtdo_parcial)
      rta = ws.informar_comprobantes_caea(:cbte_tipo => 1, :pto_vta => 3, :comprobantes => [
        { :cbte_nro => 1, :caea => '21043476341977' }, { :cbte_nro => 2, :caea => '21043476341977' },
      ])
      rta[0].should have_entries :cbte_nro => 1, :caea => '21043476341977', :resultado => 'A', :observaciones => []
      rta[1].should have_entries :cbte_nro => 2, :caea => '21043476341977', :resultado => 'R', :observaciones => [{:code => 724, :msg => 'Msg'}]
    end
    
    it "informar_caea_sin_movimientos" do
      savon.expects('FECAEASinMovimientoInformar').with(has_path('/Auth/Token' => 't',
        '/PtoVta' => 4, '/CAEA' => '21043476341977')).returns(:success)
      rta = ws.informar_caea_sin_movimientos('21043476341977', 4)
      rta.should have_entries :caea => '21043476341977', :resultado => 'A'
    end
    
    context "consultar_caea" do
      it "consultar_caea" do
        savon.expects('FECAEAConsultar').with(has_path '/Periodo' => '201101', '/Orden' => 1).returns(:success)
        ws.consultar_caea(Date.new(2011,1,1)).should have_entries :caea => '21043476341977', :fch_tope_inf => Date.new(2011,03,17)
      end
    end
    
    it "ultimo_comprobante_autorizado" do
      savon.expects('FECompUltimoAutorizado').with(has_path '/PtoVta' => 1, '/CbteTipo' => 1).returns(:success)
      ws.ultimo_comprobante_autorizado(:pto_vta => 1, :cbte_tipo => 1).should == 20
    end
    
    it "consultar_comprobante" do
      savon.expects('FECompConsultar').with(has_entries 'wsdl:PtoVta' => 1, 'wsdl:CbteTipo' => 2, 'wsdl:CbteNro' => 3).returns(:success)
      rta = ws.consultar_comprobante(:pto_vta => 1, :cbte_tipo => 2, :cbte_nro => 3)
      rta[:cod_autorizacion].should == '61023008595705'
      rta[:emision_tipo].should == 'CAE'
    end
  end
  
  context "autenticacion" do
    it "debería autenticarse usando el WSAA" do
      wsfe = Afipws::WSFE.new :cuit => '1', :cert => 'cert', :key => 'key'
      wsfe.wsaa.cert.should == 'cert'
      wsfe.wsaa.key.should == 'key'
      wsfe.wsaa.service.should == 'wsfe'
      wsfe.wsaa.expects(:login).returns({ :token => 't', :sign => 's' })
      savon.expects('FEParamGetTiposCbte').with('wsdl:Auth' => {'wsdl:Token' => 't', 'wsdl:Sign' => 's', 'wsdl:Cuit' => '1'}).returns(:success)
      wsfe.tipos_comprobantes
    end
  end
  
  context "entorno" do
    it "debería usar las url para development cuando el env es development" do
      Afipws::Client.expects(:new).with("https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl")
      Afipws::Client.expects(:new).with("https://wswhomo.afip.gov.ar/wsfev1/service.asmx?WSDL")
      wsfe = Afipws::WSFE.new :env => :development
      wsfe.env.should == :development
    end

    it "debería usar las url para production cuando el env es production" do
      Afipws::Client.expects(:new).with("https://wsaa.afip.gov.ar/ws/services/LoginCms?wsdl")
      Afipws::Client.expects(:new).with("https://servicios1.afip.gov.ar/wsfev1/service.asmx?WSDL")
      wsfe = Afipws::WSFE.new :env => 'production'
      wsfe.env.should == :production
    end
  end
  
  context "manejo de errores" do
    it "cuando hay un error" do
      savon.expects('FEParamGetTiposCbte').returns(:failure_1_error)
      expect { ws.tipos_comprobantes }.to raise_error { |e| 
        e.should be_a Afipws::WSError
        e.errors.should == [{ :code => "600", :msg => "No se corresponden token con firma" }] 
        e.message.should == "600: No se corresponden token con firma" 
      }
    end

    it "cuando hay varios errores" do
      savon.expects('FEParamGetTiposCbte').returns(:failure_2_errors)
      expect { ws.tipos_comprobantes }.to raise_error { |e| 
        e.should be_a Afipws::WSError
        e.errors.should == [{ :code => "600", :msg => "No se corresponden token con firma" }, { :code => "601", :msg => "CUIT representada no incluida en token" }] 
        e.message.should == "600: No se corresponden token con firma; 601: CUIT representada no incluida en token" 
      }
    end
  end
  
  context "cálculo de fechas y períodos" do
    it "periodo_para_consulta_caea" do
      ws.periodo_para_consulta_caea(Date.new(2011,1,1)).should == { :periodo => '201101', :orden => 1 }
      ws.periodo_para_consulta_caea(Date.new(2011,1,15)).should == { :periodo => '201101', :orden => 1 }
      ws.periodo_para_consulta_caea(Date.new(2011,1,16)).should == { :periodo => '201101', :orden => 2 }
      ws.periodo_para_consulta_caea(Date.new(2011,1,31)).should == { :periodo => '201101', :orden => 2 }
      ws.periodo_para_consulta_caea(Date.new(2011,2,2)).should == { :periodo => '201102', :orden => 1 }
    end
    
    it "fecha_inicio_quincena_siguiente" do
      fecha_inicio_quincena_siguiente(Date.new(2010,1,1)).should == Date.new(2010,1,16)
      fecha_inicio_quincena_siguiente(Date.new(2010,1,10)).should == Date.new(2010,1,16)
      fecha_inicio_quincena_siguiente(Date.new(2010,1,15)).should == Date.new(2010,1,16)
      
      fecha_inicio_quincena_siguiente(Date.new(2010,1,16)).should == Date.new(2010,2,1)
      fecha_inicio_quincena_siguiente(Date.new(2010,1,20)).should == Date.new(2010,2,1)
      fecha_inicio_quincena_siguiente(Date.new(2010,1,31)).should == Date.new(2010,2,1)
      fecha_inicio_quincena_siguiente(Date.new(2010,12,31)).should == Date.new(2011,1,1)
    end
    
    def fecha_inicio_quincena_siguiente fecha
      Date.stubs(:today => fecha)
      subject.fecha_inicio_quincena_siguiente
    end
  end
end