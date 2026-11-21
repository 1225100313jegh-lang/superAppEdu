enum Servicio {
  mensajeria('Mensajes', '💬'),
  pagos('Monedero', '👛'),
  comercio('Tienda', '🛍️'),
  transporte('Viajes', '🚕');
 
  final String nombre;
  final String emoji;
  const Servicio(this.nombre, this.emoji);
}
 
/// Hechos que ocurren en la plataforma. Los servicios NO se llaman entre sí:
/// publican eventos y los demás (lealtad, notificaciones, analítica) reaccionan.
sealed class EventoApp {
  final String id;
  final String usuarioId;
  final DateTime fecha;
  const EventoApp(this.id, this.usuarioId, this.fecha);
 
  Servicio get servicio;
 
  /// ¿Cuenta como "uso activo" del usuario? Recibir dinero es pasivo y NO cuenta.
  bool get cuentaComoUso => true;
}
 
class PagoRealizado extends EventoApp {
  final int montoCentavos;
  final String concepto;
  final Servicio origen;
  const PagoRealizado(super.id, super.usuarioId, super.fecha,
      {required this.montoCentavos, required this.concepto, required this.origen});
  @override
  Servicio get servicio => origen;
}
 
class PedidoCreado extends EventoApp {
  final String pedidoId;
  final int totalCentavos;
  const PedidoCreado(super.id, super.usuarioId, super.fecha,
      {required this.pedidoId, required this.totalCentavos});
  @override
  Servicio get servicio => Servicio.comercio;
}
 
class ViajeFinalizado extends EventoApp {
  final String viajeId;
  final int montoCentavos;
  const ViajeFinalizado(super.id, super.usuarioId, super.fecha,
      {required this.viajeId, required this.montoCentavos});
  @override
  Servicio get servicio => Servicio.transporte;
}
 
class MensajeEnviado extends EventoApp {
  final String para;
  const MensajeEnviado(super.id, super.usuarioId, super.fecha, {required this.para});
  @override
  Servicio get servicio => Servicio.mensajeria;
}
 
class DineroRecibido extends EventoApp {
  final String de;
  final int montoCentavos;
  const DineroRecibido(super.id, super.usuarioId, super.fecha, {required this.de, required this.montoCentavos});
  @override
  Servicio get servicio => Servicio.pagos;
  @override
  bool get cuentaComoUso => false;
}
 
class Ids {
  int _n = 0;
  String siguiente(String prefijo) => '$prefijo-${++_n}';
}
 
/// Bus de eventos: publicar/suscribir con tipos. Un suscriptor que falla NO derrumba a los demás.
class BusEventos {
  static const int maxReintentos = 3;
  final List<void Function(EventoApp)> _suscriptores = [];
  final List<Object> errores = [];
  final List<_EntregaFallida> _colaFallidos = [];

  int get fallidosPendientes => _colaFallidos.length;

  void suscribir<T extends EventoApp>(void Function(T) manejador) {
    _suscriptores.add((e) {
      if (e is T) manejador(e);
    });
  }

  void publicar(EventoApp e) {
    for (final s in List.of(_suscriptores)) {
      _entregar(e, s);
    }
  }

  /// Vuelve a intentar cada entrega fallida pendiente una vez.
  /// Una entrega se descarta si falla en sus tres reintentos.
  void reintentarFallidos() {
    final pendientes = List<_EntregaFallida>.of(_colaFallidos);
    _colaFallidos.clear();
    for (final entrega in pendientes) {
      try {
        entrega.suscriptor(entrega.evento);
      } catch (err) {
        errores.add(err);
        entrega.reintentos++;
        if (entrega.reintentos < maxReintentos) {
          _colaFallidos.add(entrega);
        }
      }
    }
  }

  void _entregar(EventoApp evento, void Function(EventoApp) suscriptor) {
    try {
      suscriptor(evento);
    } catch (err) {
      errores.add(err);
      _colaFallidos.add(_EntregaFallida(evento, suscriptor));
    }
  }
}

class _EntregaFallida {
  final EventoApp evento;
  final void Function(EventoApp) suscriptor;
  int reintentos = 0;

  _EntregaFallida(this.evento, this.suscriptor);
}
