# Gestión de PAU con Oracle Database — Presentación (5 min)

---

## Slide 1 — Introducción (1 min)

**GUIÓN:**

Buenos días. Somos el grupo [X] y hoy os vamos a presentar nuestro trabajo de Bases de Datos II: un sistema Oracle para la gestión logística de las Pruebas de Acceso a la Universidad, las PAU.

El problema consiste en gestionar estudiantes, sedes de examen, aulas, centros de procedencia, tribunales (vocales) y la asignación de cada estudiante a su aula y examen correspondiente, con requisitos de capacidad, vigilancia y seguridad.

El proyecto se ha desarrollado en tres entregas progresivas: esquema relacional, optimización y población de datos, y finalmente seguridad y lógica compleja. Todo está consolidado en un script único `Entrega_Final.sql` de más de 1200 líneas.

---

## Slide 2 — Esquema de la Base de Datos (1 min)

**GUIÓN:**

El modelo relacional consta de **10 tablas principales** y **14 claves foráneas**. Las tablas clave son:

- **VOCAL** — los profesores que vigilan y gestionan los exámenes.
- **SEDE y AULA** — los lugares físicos donde se realizan los exámenes, con capacidad limitada.
- **ESTUDIANTE y ANE** — los alumnos, con soporte para adaptaciones no evaluables.
- **EXAMEN y ASISTENCIA** — las sesiones de examen y el registro de asistencia.
- **EXAMEN_MATERIA y ESTUDIANTE_MATERIA** — relaciones muchos a muchos para gestionar qué materias tiene cada examen y cada estudiante.

Además, usamos una **tabla externa** (`estudiantes_ext`) que lee directamente de un CSV mediante Oracle Loader, y un **vista materializada** con refresco diario (`VM_ESTUDIANTES`) para optimizar consultas frecuentes.

---

## Slide 3 — Procedimientos y Paquetes (1 min 30 s)

**GUIÓN:**

Hemos implementado varios procedimientos y paquetes PL/SQL que automatizan la lógica de negocio:

- **PR_INSERTA_MATERIAS y PR_MATRICULA_ESTUDIANTES** — parsean una lista de materias separadas por comas desde el CSV y matriculan a los estudiantes automáticamente.

- **PK_ASIGNA** — paquete que asigna centros a sedes mediante un algoritmo greedy: primero empareja institutos con sedes del mismo nombre, y luego asigna los centros restantes a la sede con más plazas libres.

- **PK_OCUPACION** — paquete de análisis que verifica la ocupación máxima de las aulas, detecta vocales duplicados en el mismo horario, y comprueba que el ratio estudiante-vocal no supere el límite permitido.

- **DESPISTE** — procedimiento de reubicación de última hora: si un estudiante se equivoca de sede, podemos moverlo con sus exámenes a un aula con sitio disponible en menos de una hora.

- **MIGRAR_CENTRO** — al cambiar un centro de sede, un trigger dispara automáticamente la reasignación de todos sus estudiantes a las nuevas aulas correspondientes.

---

## Slide 4 — Seguridad (1 min)

**GUIÓN:**

La seguridad es un pilar fundamental del proyecto, con tres capas:

**Primera capa — Roles:** Definimos tres roles de acceso. `ROL_ESTUDIANTE` permite al alumno ver solo sus propios datos y asignaciones. `ROL_VOCAL` permite a los profesores gestionar asistencia y su sede. `ROL_ACCESO` es un rol de servicio con permisos globales.

**Segunda capa — VPD (Virtual Private Database):** Implementamos una política de seguridad a nivel de fila que aplica `Usuario_BD = USER` sobre la tabla ESTUDIANTE. Cada usuario solo ve su propia fila, ni siquiera puede listar otros estudiantes aunque comparta rol.

**Tercera capa — Usuarios dinámicos:** El paquete `PK_SEGURIDAD_PAU` crea cuentas Oracle automáticamente (`EST_<DNI>` para estudiantes, `VOC_<DNI>` para vocales) con contraseña aleatoria, política de bloqueo tras 5 intentos fallidos y caducidad a los 30 días.

Además, configuramos una **política de auditoría unificada** que registra cualquier modificación en la tabla ASISTENCIA.

---

## Slide 5 — Pruebas y Conclusiones (30 s)

**GUIÓN:**

Para validar el sistema, disponemos de un script `Pruebas_Completas.sql` con **20 tests funcionales** que cubren: inserción de datos, asignación de sedes, verificación de ocupación, comprobación de restricciones, creación de usuarios y auditoría.

El código ha sido revisado contra la rúbrica mediante verificación con tres modelos de IA diferentes, generando un reporte unificado que confirma la corrección de todas las funcionalidades requeridas tras los bugs corregidos en la versión final.

**En resumen:** hemos construido un sistema Oracle completo y funcional para la gestión de las PAU, con esquema relacional, lógica de negocio en PL/SQL y una arquitectura de seguridad multicapa adaptada a un entorno real de examen universitario.

Muchas gracias. ¿Alguna pregunta?
