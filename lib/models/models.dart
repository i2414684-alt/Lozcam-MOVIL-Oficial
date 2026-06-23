/// Modelos ligeros usados por la app (y por los datos de ejemplo).
class Obra {
  final int id;
  final String nombre, tipo, distrito, estado, monto, direccion, colorKey;
  final int avance;
  final double lat, lng;
  final int radioMetros; // radio permitido para marcar asistencia (default 200)
  const Obra(this.id, this.nombre, this.tipo, this.distrito, this.estado,
      this.avance, this.monto, this.direccion, this.lat, this.lng, this.colorKey,
      {this.radioMetros = 200});
}

class Empleado {
  final String id, nombre, rol, iniciales, estado, colorKey, telefono;
  const Empleado(this.id, this.nombre, this.rol, this.iniciales, this.estado,
      this.colorKey, this.telefono);
}

class Tarea {
  final String titulo, contexto, vence, prioridad;
  final bool done;
  const Tarea(this.titulo, this.contexto, this.vence, this.prioridad, this.done);
}

class GrupoTareas {
  final String obra;
  final List<Tarea> items;
  const GrupoTareas(this.obra, this.items);
}

class Asistencia {
  final String nombre, detalle, estado; // presente | tardanza | inasistencia
  const Asistencia(this.nombre, this.detalle, this.estado);
}

class Fase {
  final String nombre;
  final int pct;
  const Fase(this.nombre, this.pct);
}

class Informe {
  final String titulo, autor, pct, texto;
  final bool fotos;
  const Informe(this.titulo, this.autor, this.pct, this.texto, this.fotos);
}

class Contacto {
  final String nombre, rol, iniciales, colorKey;
  const Contacto(this.nombre, this.rol, this.iniciales, this.colorKey);
}
