-- ============================================================================
-- BASES DE DATOS II -- TRABAJO GRUPO PAU
-- Universidad de Malaga -- ETSI Informatica -- 2025-26
--
-- SCRIPT UNICO DE ENTREGA
-- Incluye Primera, Segunda y Tercera Entrega + Rubrica completa
-- ============================================================================
-- INSTRUCCIONES:
--   1. Conectarse como SYS a la PDB
--   2. Copiar datos-estudiantes-pau.csv al directorio dpdump de Oracle (ej: C:\app\alumnos\admin\orcl\dpdump)
--   3. Ejecutar este script completo
-- ============================================================================


-- ============================================================================
-- PARTE 1: PRIMERA ENTREGA - ESQUEMA Y DATOS
-- ============================================================================

-- Creamos tablespaces (si no existen)
CREATE TABLESPACE TS_PAU 
DATAFILE 'ts_pau.dbf' SIZE 100M 
AUTOEXTEND ON;

CREATE TABLESPACE TS_INDICES 
DATAFILE 'ts_indices.dbf' SIZE 50M;

-- Crear usuario PAU (si no existe)
CREATE USER PAU IDENTIFIED BY pau DEFAULT TABLESPACE TS_PAU 
  QUOTA UNLIMITED ON TS_PAU QUOTA UNLIMITED ON TS_INDICES;

-- En lugar de GRANT DBA, damos permisos especificos
GRANT CONNECT, RESOURCE TO PAU;
GRANT CREATE VIEW, CREATE MATERIALIZED VIEW, CREATE PROCEDURE, 
      CREATE SEQUENCE, CREATE TRIGGER, CREATE SYNONYM, CREATE PUBLIC SYNONYM TO PAU;

-- Directorio para tabla externa
CREATE OR REPLACE DIRECTORY directorio_ext AS 'C:\app\alumnos\admin\orcl\dpdump';
GRANT READ, WRITE ON DIRECTORY directorio_ext TO PAU;

-- Permisos adicionales
GRANT EXECUTE ON SYS.DBMS_RANDOM TO PAU;
GRANT EXECUTE ON SYS.DBMS_RLS TO PAU;
-- Permiso para crear usuarios (PK_SEGURIDAD_PAU)
GRANT CREATE USER TO PAU;


-- ============================================================================
-- CONECTAR COMO PAU a partir de aqui
-- ============================================================================
ALTER SESSION SET CURRENT_SCHEMA = PAU;

-- Drop objetos existentes en orden correcto
BEGIN
  FOR rec IN (SELECT mview_name FROM all_mviews WHERE owner = 'PAU') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW PAU.' || rec.mview_name;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

BEGIN
  FOR rec IN (SELECT synonym_name FROM dba_synonyms WHERE owner = 'PUBLIC' AND table_owner = 'PAU') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM ' || rec.synonym_name;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

BEGIN
  EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM S_ESTUDIANTES';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  FOR rec IN (SELECT object_name, object_type FROM dba_objects 
              WHERE owner = 'PAU' AND object_type IN ('PROCEDURE','PACKAGE','FUNCTION','TRIGGER','VIEW')) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' || rec.object_type || ' PAU.' || rec.object_name;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

BEGIN
   FOR rec IN (SELECT table_name FROM dba_tables WHERE owner = 'PAU' ORDER BY table_name DESC) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP TABLE PAU.' || rec.table_name || ' CASCADE CONSTRAINTS PURGE';
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
   END LOOP;
END;
/

BEGIN
   FOR rec IN (SELECT sequence_name FROM dba_sequences WHERE sequence_owner = 'PAU') LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP SEQUENCE PAU.' || rec.sequence_name;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
   END LOOP;
END;
/


-- ============================================================================
-- CREACION DE TABLAS
-- ============================================================================

CREATE TABLE VOCAL 
    ( 
     DNI            VARCHAR2 (20)  NOT NULL , 
     Nombre         VARCHAR2 (50)  NOT NULL , 
     Apellidos      VARCHAR2 (100)  NOT NULL , 
     Tipo           VARCHAR2 (100) , 
     Cargo          VARCHAR2 (100) , 
     Materia_Codigo VARCHAR2 (20),
     Usuario_BD     VARCHAR2 (30)
    ) 
;
ALTER TABLE VOCAL ADD CONSTRAINT VOCAL_PK PRIMARY KEY ( DNI ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE MATERIA 
    ( 
     Codigo VARCHAR2 (20)  NOT NULL , 
     Nombre VARCHAR2 (100)  NOT NULL 
    ) 
;
ALTER TABLE MATERIA ADD CONSTRAINT MATERIA_PK PRIMARY KEY ( Codigo ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE SEDE 
    ( 
     Codigo                 VARCHAR2 (20)  NOT NULL , 
     Nombre                 VARCHAR2 (100)  NOT NULL , 
     Tipo                   VARCHAR2 (100) , 
     Vocal_Secretario_DNI   VARCHAR2 (20)  NOT NULL , 
     Vocal_Responsable_DNI  VARCHAR2 (20)  NOT NULL 
    ) 
;
ALTER TABLE SEDE ADD CONSTRAINT SEDE_PK PRIMARY KEY ( Codigo ) 
  USING INDEX TABLESPACE TS_INDICES ;

CREATE UNIQUE INDEX SEDE_UQ_VOCAL_RESP ON SEDE 
    ( Vocal_Responsable_DNI ASC ) TABLESPACE TS_INDICES;
CREATE UNIQUE INDEX SEDE_UQ_VOCAL_SEC ON SEDE 
    ( Vocal_Secretario_DNI ASC ) TABLESPACE TS_INDICES;


CREATE TABLE CENTRO 
    ( 
     Codigo      VARCHAR2 (20)  NOT NULL , 
     Nombre      VARCHAR2 (100)  NOT NULL , 
     Direccion   VARCHAR2 (200) , 
     Poblacion   VARCHAR2 (200) , 
     Sede_Codigo VARCHAR2 (20) 
    ) 
;
ALTER TABLE CENTRO ADD CONSTRAINT CENTRO_PK PRIMARY KEY ( Codigo ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE AULA 
    ( 
     Codigo           VARCHAR2 (20)  NOT NULL , 
     Capacidad        NUMBER  NOT NULL , 
     Capacidad_Examen NUMBER  NOT NULL , 
     Descripcion      VARCHAR2 (500) , 
     Sede_Codigo      VARCHAR2 (20)  NOT NULL
    ) 
;
ALTER TABLE AULA ADD CONSTRAINT AULA_PK PRIMARY KEY ( Codigo ) 
  USING INDEX TABLESPACE TS_INDICES ;

ALTER TABLE AULA ADD CONSTRAINT CHK_AULA_CAPACIDAD CHECK (Capacidad > 0);
ALTER TABLE AULA ADD CONSTRAINT CHK_AULA_CAP_EXAMEN 
  CHECK (Capacidad_Examen > 0 AND Capacidad_Examen <= Capacidad);


CREATE TABLE ESTUDIANTE 
    ( 
     DNI           VARCHAR2 (20)  NOT NULL , 
     Nombre        VARCHAR2 (50)  NOT NULL , 
     Apellidos     VARCHAR2 (100)  NOT NULL , 
     Telefono      VARCHAR2 (50)  NOT NULL , 
     Correo        VARCHAR2 (150) , 
     Centro_Codigo VARCHAR2 (20)  NOT NULL,
     Usuario_BD    VARCHAR2 (30)
    ) 
;
ALTER TABLE ESTUDIANTE ADD CONSTRAINT ESTUDIANTE_PK PRIMARY KEY ( DNI ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE ANE 
    ( 
     DNI        VARCHAR2 (20)  NOT NULL , 
     Descabezar CHAR (1) , 
     AulaAparte CHAR (1) 
    ) 
;
ALTER TABLE ANE ADD CONSTRAINT ANE_PK PRIMARY KEY ( DNI ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE EXAMEN 
    ( 
     FechayHora   DATE  NOT NULL , 
     Aula_Codigo  VARCHAR2 (20)  NOT NULL , 
     Vocal_DNI    VARCHAR2 (20)  NOT NULL,
     Num_Estudiantes_Presentes NUMBER
    ) 
;
ALTER TABLE EXAMEN ADD CONSTRAINT EXAMEN_PK PRIMARY KEY ( FechayHora ) 
  USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE EXAMEN_MATERIA 
    ( 
     Examen_FechayHora DATE  NOT NULL , 
     Materia_Codigo    VARCHAR2 (20)  NOT NULL 
    ) 
;
ALTER TABLE EXAMEN_MATERIA ADD CONSTRAINT EXAMEN_MATERIA_PK 
  PRIMARY KEY ( Examen_FechayHora, Materia_Codigo ) USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE EXAMEN_VOCAL_Vigilantes 
    ( 
     Examen_FechayHora DATE  NOT NULL , 
     Vocal_DNI         VARCHAR2 (20)  NOT NULL 
    ) 
;
ALTER TABLE EXAMEN_VOCAL_Vigilantes ADD CONSTRAINT EXAMEN_VOCAL_VIGILANTES_PK 
  PRIMARY KEY ( Examen_FechayHora, Vocal_DNI ) USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE ESTUDIANTE_MATERIA 
    ( 
     Estudiante_DNI VARCHAR2 (20)  NOT NULL , 
     Materia_Codigo VARCHAR2 (20)  NOT NULL 
    ) 
;
ALTER TABLE ESTUDIANTE_MATERIA ADD CONSTRAINT ESTUDIANTE_MATERIA_PK 
  PRIMARY KEY ( Estudiante_DNI, Materia_Codigo ) USING INDEX TABLESPACE TS_INDICES ;


CREATE TABLE ASISTENCIA 
    ( 
     Asiste            CHAR (1)  NOT NULL , 
     Entrega           CHAR (1) , 
     Examen_FechayHora DATE  NOT NULL , 
     Estudiante_DNI    VARCHAR2 (20)  NOT NULL , 
     Materia_Codigo    VARCHAR2 (20)  NOT NULL,
     Aula_Codigo       VARCHAR2 (20),
     Sede_Codigo       VARCHAR2 (20)
    ) 
;
ALTER TABLE ASISTENCIA ADD CONSTRAINT ASISTENCIA_PK 
  PRIMARY KEY ( Examen_FechayHora, Estudiante_DNI, Materia_Codigo ) 
  USING INDEX TABLESPACE TS_INDICES ;


-- Tabla de auditoria (punto extra)
CREATE TABLE LOG_ASISTENCIA (
    Usuario_Modifica VARCHAR2(50),
    Fecha_Cambio     DATE,
    DNI_Estudiante   VARCHAR2(20),
    Materia          VARCHAR2(20),
    Accion           VARCHAR2(20)
);


-- ============================================================================
-- FOREIGN KEYS
-- ============================================================================

ALTER TABLE ANE ADD CONSTRAINT ANE_ESTUDIANTE_FK 
  FOREIGN KEY ( DNI ) REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ASISTENCIA ADD CONSTRAINT ASISTENCIA_ESTUDIANTE_FK 
  FOREIGN KEY ( Estudiante_DNI ) REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ASISTENCIA ADD CONSTRAINT ASISTENCIA_EXAMEN_FK 
  FOREIGN KEY ( Examen_FechayHora ) REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE ASISTENCIA ADD CONSTRAINT ASISTENCIA_MATERIA_FK 
  FOREIGN KEY ( Materia_Codigo ) REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE AULA ADD CONSTRAINT AULA_SEDE_FK 
  FOREIGN KEY ( Sede_Codigo ) REFERENCES SEDE ( Codigo ) ;

ALTER TABLE CENTRO ADD CONSTRAINT CENTRO_SEDE_FK 
  FOREIGN KEY ( Sede_Codigo ) REFERENCES SEDE ( Codigo ) ;

ALTER TABLE ESTUDIANTE ADD CONSTRAINT ESTUDIANTE_CENTRO_FK 
  FOREIGN KEY ( Centro_Codigo ) REFERENCES CENTRO ( Codigo ) ;

ALTER TABLE ESTUDIANTE_MATERIA ADD CONSTRAINT EM_ESTUDIANTE_FK 
  FOREIGN KEY ( Estudiante_DNI ) REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ESTUDIANTE_MATERIA ADD CONSTRAINT ESTUDIANTE_MATERIA_MATERIA_FK 
  FOREIGN KEY ( Materia_Codigo ) REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE EXAMEN ADD CONSTRAINT EXAMEN_AULA_FK 
  FOREIGN KEY ( Aula_Codigo ) REFERENCES AULA ( Codigo ) ;

ALTER TABLE EXAMEN_MATERIA ADD CONSTRAINT EXAMEN_MATERIA_EXAMEN_FK 
  FOREIGN KEY ( Examen_FechayHora ) REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE EXAMEN_MATERIA ADD CONSTRAINT EXAMEN_MATERIA_MATERIA_FK 
  FOREIGN KEY ( Materia_Codigo ) REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE EXAMEN ADD CONSTRAINT EXAMEN_VOCAL_FK 
  FOREIGN KEY ( Vocal_DNI ) REFERENCES VOCAL ( DNI ) ;

ALTER TABLE EXAMEN_VOCAL_Vigilantes ADD CONSTRAINT EVV_EXAMEN_FK 
  FOREIGN KEY ( Examen_FechayHora ) REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE EXAMEN_VOCAL_Vigilantes ADD CONSTRAINT EVV_VOCAL_FK 
  FOREIGN KEY ( Vocal_DNI ) REFERENCES VOCAL ( DNI ) ;

ALTER TABLE SEDE ADD CONSTRAINT SEDE_VOCAL_RESP_FK 
  FOREIGN KEY ( Vocal_Responsable_DNI ) REFERENCES VOCAL ( DNI ) ;

ALTER TABLE SEDE ADD CONSTRAINT SEDE_VOCAL_SEC_FK 
  FOREIGN KEY ( Vocal_Secretario_DNI ) REFERENCES VOCAL ( DNI ) ;

ALTER TABLE VOCAL ADD CONSTRAINT Vocal_Materia_FK 
  FOREIGN KEY ( Materia_Codigo ) REFERENCES MATERIA ( Codigo ) ;


-- ============================================================================
-- IMPORTACION DE DATOS: VOCAL, MATERIA, SEDE
-- ============================================================================

-- Los datos se importan manualmente mediante SQL Developer:
--   - VOCALES desde Vocales.xlsx     → importar a tabla VOCAL
--   - MATERIAS desde Materias.csv    → importar a tabla MATERIA
--   - SEDES desde Sedes.xlsx         → importar a tabla SEDE


-- ============================================================================
-- TABLA EXTERNA Y VISTA DE ESTUDIANTES
-- ============================================================================

CREATE TABLE estudiantes_ext (
    centro          VARCHAR2(100),
    nombre          VARCHAR2(100),
    apellido1       VARCHAR2(100),
    apellido2       VARCHAR2(100),
    dni             VARCHAR2(20),
    telefono        VARCHAR2(50),
    detalle_materias VARCHAR2(4000)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY directorio_ext
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        CHARACTERSET UTF8
        FIELDS TERMINATED BY ';'
        OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
        (centro, nombre, apellido1, apellido2, dni, telefono, detalle_materias)
    )
    LOCATION ('datos-estudiantes-pau.csv')
);

CREATE OR REPLACE VIEW v_estudiantes AS
SELECT dni, nombre, apellido1 ||' '||apellido2 apellidos,
 telefono,
 substr(nombre,1,1)||apellido1||substr(dni,6,3) ||'@uncorreo.es' correo,
 centro, detalle_materias
FROM estudiantes_ext
WHERE dni IS NOT NULL;


-- ============================================================================
-- PROCEDIMIENTOS PRIMERA ENTREGA
-- ============================================================================

CREATE OR REPLACE PROCEDURE PR_INSERTA_MATERIAS(
  PESTDNI IN VARCHAR2,
  PDETALLE_MATERIAS IN VARCHAR2
) AS
  v_materia VARCHAR2(200);
  v_resto   VARCHAR2(4000);
  v_pos     NUMBER;
  v_cod     MATERIA.Codigo%TYPE;
BEGIN
  v_resto := PDETALLE_MATERIAS;
  LOOP
    v_pos := INSTR(v_resto, ',');
    IF v_pos > 0 THEN
      v_materia := TRIM(SUBSTR(v_resto, 1, v_pos - 1));
      v_resto   := TRIM(SUBSTR(v_resto, v_pos + 1));
    ELSE
      v_materia := TRIM(v_resto);
      v_resto   := NULL;
    END IF;

    BEGIN
      SELECT Codigo INTO v_cod
      FROM MATERIA
      WHERE UPPER(Nombre) = UPPER(v_materia);

      INSERT INTO ESTUDIANTE_MATERIA(Estudiante_DNI, Materia_Codigo)
      VALUES(PESTDNI, v_cod);
    EXCEPTION
      WHEN NO_DATA_FOUND THEN NULL;
      WHEN DUP_VAL_ON_INDEX THEN NULL;
    END;

    EXIT WHEN v_resto IS NULL OR v_resto = '';
  END LOOP;
  COMMIT;
END PR_INSERTA_MATERIAS;
/

CREATE OR REPLACE PROCEDURE PR_MATRICULA_ESTUDIANTES AS
  CURSOR c IS
    SELECT dni, detalle_materias
    FROM v_estudiantes
    WHERE detalle_materias IS NOT NULL;
BEGIN
  FOR est IN c LOOP
    PR_INSERTA_MATERIAS(est.dni, est.detalle_materias);
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20010, 'Error en matriculacion: ' || SQLERRM);
END PR_MATRICULA_ESTUDIANTES;
/

CREATE OR REPLACE PROCEDURE PR_RELLENA_AULAS(
  PNUMAULAS  IN NUMBER,
  PCAPACIDAD IN NUMBER
) AS
  v_codigo VARCHAR2(20);
BEGIN
  FOR s IN (SELECT Codigo FROM SEDE) LOOP
    FOR i IN 1..PNUMAULAS LOOP
      v_codigo := s.Codigo || '_' || TO_CHAR(i);
      INSERT INTO AULA(Codigo, Capacidad, Capacidad_Examen, Sede_Codigo)
      VALUES(v_codigo, PCAPACIDAD, PCAPACIDAD / 2, s.Codigo);
    END LOOP;
  END LOOP;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20011, 'Error rellenando aulas: ' || SQLERRM);
END PR_RELLENA_AULAS;
/

CREATE OR REPLACE PROCEDURE PR_BORRA_AULA_SEDE(
  PCODIGOSEDE IN SEDE.Codigo%TYPE
) AS
BEGIN
  DELETE FROM AULA WHERE Sede_Codigo = PCODIGOSEDE;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20012, 'Error borrando aulas de sede: ' || SQLERRM);
END PR_BORRA_AULA_SEDE;
/

CREATE OR REPLACE PROCEDURE PR_BORRA_AULAS AS
BEGIN
  FOR s IN (SELECT Codigo FROM SEDE) LOOP
    PR_BORRA_AULA_SEDE(s.Codigo);
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20013, 'Error en borrado total de aulas: ' || SQLERRM);
END PR_BORRA_AULAS;
/

-- PR_BORRA_AULA: borra un aula individual (requisito rubrica)
CREATE OR REPLACE PROCEDURE PR_BORRA_AULA(
  PCODIGOAULA IN AULA.Codigo%TYPE
) AS
BEGIN
  DELETE FROM AULA WHERE Codigo = PCODIGOAULA;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20014, 'Error borrando aula: ' || SQLERRM);
END PR_BORRA_AULA;
/

-- Trigger de auditoria (punto extra rubrica)
CREATE OR REPLACE TRIGGER TR_AUDIT_ASISTENCIA
AFTER INSERT OR UPDATE OR DELETE ON ASISTENCIA
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO LOG_ASISTENCIA VALUES (USER, SYSDATE, :NEW.Estudiante_DNI, :NEW.Materia_Codigo, 'INSERT');
    ELSIF UPDATING THEN
        INSERT INTO LOG_ASISTENCIA VALUES (USER, SYSDATE, :OLD.Estudiante_DNI, :OLD.Materia_Codigo, 'UPDATE');
    ELSE
        INSERT INTO LOG_ASISTENCIA VALUES (USER, SYSDATE, :OLD.Estudiante_DNI, :OLD.Materia_Codigo, 'DELETE');
    END IF;
END;
/


-- ============================================================================
-- PARTE 2: SEGUNDA ENTREGA - INDICES, MV, SINONIMO, CENTROS, ASIGNACION
-- ============================================================================

-- Reconstruir indices existentes en TS_INDICES
DECLARE
  CURSOR c_indices IS
    SELECT index_name FROM user_indexes
    WHERE tablespace_name != 'TS_INDICES' OR tablespace_name IS NULL;
BEGIN
  FOR idx IN c_indices LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER INDEX ' || idx.index_name || ' REBUILD TABLESPACE TS_INDICES';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

-- Indices adicionales
CREATE INDEX IDX_ESTUDIANTE_APELLIDOS_UP 
  ON ESTUDIANTE (UPPER(Apellidos)) TABLESPACE TS_INDICES;
CREATE INDEX IDX_ESTUDIANTE_CORREO 
  ON ESTUDIANTE (Correo) TABLESPACE TS_INDICES;
CREATE BITMAP INDEX IDX_ESTUDIANTE_CENTRO_BM 
  ON ESTUDIANTE (Centro_Codigo) TABLESPACE TS_INDICES;

-- Indices para busquedas frecuentes
CREATE INDEX IDX_ASISTENCIA_EST 
  ON ASISTENCIA (Estudiante_DNI) TABLESPACE TS_INDICES;
CREATE INDEX IDX_ASISTENCIA_EXAMEN 
  ON ASISTENCIA (Examen_FechayHora) TABLESPACE TS_INDICES;

-- Secuencia y trigger para centros
CREATE SEQUENCE SEQ_CENTROS;

CREATE OR REPLACE TRIGGER tr_centros
BEFORE INSERT ON CENTRO 
FOR EACH ROW
BEGIN
    IF :new.Codigo IS NULL THEN
        :new.Codigo := TO_CHAR(SEQ_CENTROS.NEXTVAL);
    END IF;
END tr_centros;
/


-- ============================================================================
-- POBLAR CENTROS Y ESTUDIANTES
-- ============================================================================

-- Insertar centros desde la vista
INSERT INTO CENTRO (Nombre) 
SELECT DISTINCT centro FROM v_estudiantes;

COMMIT;

-- Insertar estudiantes desde la vista
INSERT INTO ESTUDIANTE (DNI, Nombre, Apellidos, Telefono, Correo, Centro_Codigo)
SELECT 
    v.dni, 
    v.nombre, 
    v.apellidos, 
    v.telefono, 
    v.correo, 
    c.Codigo
FROM V_ESTUDIANTES v
JOIN CENTRO c ON UPPER(v.centro) = UPPER(c.Nombre);

COMMIT;

-- Matricular estudiantes
EXEC PR_MATRICULA_ESTUDIANTES;

-- Vista materializada y sinonimo (conectar como PAU para evitar restricciones de SYS)
-- CAMBIAR a conexion como usuario PAU en SQL Developer antes de continuar
-- (ALTER SESSION SET CURRENT_SCHEMA no es suficiente; debe ser conexion real como PAU)

CREATE MATERIALIZED VIEW PAU.VM_ESTUDIANTES
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
START WITH TRUNC(SYSDATE + 1)
NEXT TRUNC(SYSDATE + 1)
AS
SELECT e.DNI, e.Nombre, e.Apellidos, e.Telefono, e.Correo, c.Nombre AS Centro
FROM PAU.ESTUDIANTE e
JOIN PAU.CENTRO c ON e.Centro_Codigo = c.Codigo;

CREATE PUBLIC SYNONYM S_ESTUDIANTES FOR PAU.VM_ESTUDIANTES;

-- CAMBIAR a conexion como SYS en SQL Developer antes de continuar
ALTER SESSION SET CURRENT_SCHEMA = PAU;


-- ============================================================================
-- PAQUETE PK_ASIGNA
-- ============================================================================

CREATE OR REPLACE PACKAGE PK_ASIGNA AS
    FUNCTION F_PLAZAS(PSEDE IN VARCHAR2) RETURN NUMBER;
    PROCEDURE PR_ASIGNA_SEDE;
END PK_ASIGNA;
/

CREATE OR REPLACE PACKAGE BODY PK_ASIGNA AS

    FUNCTION F_PLAZAS(PSEDE IN VARCHAR2) RETURN NUMBER AS
        v_capacidad NUMBER;
        v_estudiantes NUMBER;
    BEGIN
        SELECT NVL(SUM(CAPACIDAD_EXAMEN), 0) INTO v_capacidad
        FROM AULA WHERE SEDE_CODIGO = PSEDE;

        SELECT NVL(COUNT(*), 0) INTO v_estudiantes
        FROM ESTUDIANTE e
        JOIN CENTRO c ON e.CENTRO_CODIGO = c.CODIGO
        WHERE c.SEDE_CODIGO = PSEDE;

        RETURN v_capacidad - v_estudiantes;
    END F_PLAZAS;

    PROCEDURE PR_ASIGNA_SEDE AS
        e_sin_espacio EXCEPTION;
        
        CURSOR c_centros_pendientes IS
            SELECT c.CODIGO, COUNT(e.DNI) as total_estudiantes
            FROM CENTRO c
            LEFT JOIN ESTUDIANTE e ON c.CODIGO = e.CENTRO_CODIGO
            WHERE c.SEDE_CODIGO IS NULL
            GROUP BY c.CODIGO
            ORDER BY total_estudiantes DESC;

        v_mejor_sede VARCHAR2(50);
        v_max_plazas NUMBER;
    BEGIN
        -- Auto-asignar centros que son institutos
        UPDATE CENTRO c
        SET SEDE_CODIGO = (
            SELECT s.CODIGO 
            FROM SEDE s 
            WHERE UPPER(s.NOMBRE) = UPPER(c.NOMBRE) 
              AND UPPER(s.TIPO) = 'INSTITUTO'
        )
        WHERE EXISTS (
            SELECT 1 
            FROM SEDE s 
            WHERE UPPER(s.NOMBRE) = UPPER(c.NOMBRE) 
              AND UPPER(s.TIPO) = 'INSTITUTO'
        );

        -- Recorrer centros pendientes
        FOR v_centro IN c_centros_pendientes LOOP
            SELECT CODIGO, plazas_libres INTO v_mejor_sede, v_max_plazas
            FROM (
                SELECT CODIGO, PK_ASIGNA.F_PLAZAS(CODIGO) as plazas_libres
                FROM SEDE
                ORDER BY plazas_libres DESC
            )
            WHERE ROWNUM = 1;

            IF v_max_plazas >= v_centro.total_estudiantes THEN
                UPDATE CENTRO
                SET SEDE_CODIGO = v_mejor_sede
                WHERE CODIGO = v_centro.CODIGO;
            ELSE
                RAISE e_sin_espacio;
            END IF;
        END LOOP;

        COMMIT;

    EXCEPTION
        WHEN e_sin_espacio THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 
              'Error: No hay plazas suficientes en ninguna sede.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_ASIGNA_SEDE;

END PK_ASIGNA;
/


-- ============================================================================
-- PARTE 3: TERCERA ENTREGA - OCUPACION, SEGURIDAD, TRIGGERS
-- ============================================================================

-- Vistas de Ocupacion
CREATE OR REPLACE VIEW V_OCUPACION_ASIGNADA AS
SELECT S.Codigo AS Sede_Codigo, S.Nombre AS Sede_Nombre,
       E.Aula_Codigo, E.FechayHora AS Fecha_Examen,
       COUNT(A.Estudiante_DNI) AS Numero_Estudiantes_Asignados
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN ASISTENCIA A ON E.FechayHora = A.Examen_FechayHora
GROUP BY S.Codigo, S.Nombre, E.Aula_Codigo, E.FechayHora;

CREATE OR REPLACE VIEW V_OCUPACION AS
SELECT S.Codigo AS Sede_Codigo, S.Nombre AS Sede_Nombre,
       E.Aula_Codigo, E.FechayHora AS Fecha_Examen,
       COUNT(A.Estudiante_DNI) AS Numero_Estudiantes_Asisten
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN ASISTENCIA A ON E.FechayHora = A.Examen_FechayHora
WHERE A.Asiste = 'S'
GROUP BY S.Codigo, S.Nombre, E.Aula_Codigo, E.FechayHora;

CREATE OR REPLACE VIEW V_VIGILANTES AS
SELECT S.Codigo AS Sede_Codigo, S.Nombre AS Sede_Nombre,
       E.Aula_Codigo, E.FechayHora AS Fecha_Examen,
       COUNT(V.Vocal_DNI) AS Numero_Vigilantes
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN EXAMEN_VOCAL_Vigilantes V ON E.FechayHora = V.Examen_FechayHora
GROUP BY S.Codigo, S.Nombre, E.Aula_Codigo, E.FechayHora;


-- Paquete PK_OCUPACION
CREATE OR REPLACE PACKAGE PK_OCUPACION AS
    FUNCTION OCUPACION_MAXIMA(p_sede VARCHAR2, p_aula VARCHAR2) RETURN NUMBER;
    FUNCTION OCUPACION_OK RETURN BOOLEAN;
    FUNCTION VOCAL_DUPLICADO(p_vocal_dni VARCHAR2) RETURN BOOLEAN;
    FUNCTION VOCALES_DUPLICADOS RETURN BOOLEAN;
    FUNCTION VOCAL_RATIO(p_ratio NUMBER) RETURN BOOLEAN;
END PK_OCUPACION;
/

CREATE OR REPLACE PACKAGE BODY PK_OCUPACION AS

    FUNCTION OCUPACION_MAXIMA(p_sede VARCHAR2, p_aula VARCHAR2) RETURN NUMBER AS
        v_max_personas NUMBER;
    BEGIN
        SELECT NVL(MAX(
            (SELECT COUNT(*) FROM ASISTENCIA WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = p_aula) +
            (SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes 
                  WHERE Examen_FechayHora = E.FechayHora
            ))
        ), 0)
        INTO v_max_personas
        FROM EXAMEN E
        JOIN AULA A ON E.Aula_Codigo = A.Codigo
        WHERE A.Sede_Codigo = p_sede AND A.Codigo = p_aula;

        RETURN v_max_personas;
    END OCUPACION_MAXIMA;

    FUNCTION OCUPACION_OK RETURN BOOLEAN AS
        v_infracciones NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_infracciones
        FROM EXAMEN E
        JOIN AULA A ON E.Aula_Codigo = A.Codigo
        WHERE E.FechayHora > SYSDATE
        AND (
            (SELECT COUNT(*) FROM ASISTENCIA 
              WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo) > A.Capacidad_Examen
            OR
            ((SELECT COUNT(*) FROM ASISTENCIA 
               WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo) +
             (SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes 
                  WHERE Examen_FechayHora = E.FechayHora
             ))) > A.Capacidad
        );

        RETURN (v_infracciones = 0);
    END OCUPACION_OK;

    FUNCTION VOCAL_DUPLICADO(p_vocal_dni VARCHAR2) RETURN BOOLEAN AS
        v_max_asignaciones NUMBER;
    BEGIN
        SELECT NVL(MAX(num_asignaciones), 0) INTO v_max_asignaciones
        FROM (
            SELECT FechayHora, COUNT(DISTINCT Aula_Codigo) as num_asignaciones
            FROM (
                SELECT FechayHora, Aula_Codigo, Vocal_DNI FROM EXAMEN
                UNION
                SELECT E.FechayHora, E.Aula_Codigo, V.Vocal_DNI
                FROM EXAMEN_VOCAL_Vigilantes V
                JOIN EXAMEN E ON V.Examen_FechayHora = E.FechayHora
            )
            WHERE Vocal_DNI = p_vocal_dni
            GROUP BY FechayHora
        );

        RETURN (v_max_asignaciones > 1);
    END VOCAL_DUPLICADO;

    FUNCTION VOCALES_DUPLICADOS RETURN BOOLEAN AS
        v_max_global NUMBER;
    BEGIN
        SELECT NVL(MAX(num_asignaciones), 0) INTO v_max_global
        FROM (
            SELECT Vocal_DNI, FechayHora, 
                   COUNT(DISTINCT Aula_Codigo) as num_asignaciones
            FROM (
                SELECT FechayHora, Aula_Codigo, Vocal_DNI FROM EXAMEN
                UNION
                SELECT E.FechayHora, E.Aula_Codigo, V.Vocal_DNI
                FROM EXAMEN_VOCAL_Vigilantes V
                JOIN EXAMEN E ON V.Examen_FechayHora = E.FechayHora
            )
            GROUP BY Vocal_DNI, FechayHora
        );

        RETURN (v_max_global > 1);
    END VOCALES_DUPLICADOS;

    FUNCTION VOCAL_RATIO(p_ratio NUMBER) RETURN BOOLEAN AS
        v_infracciones NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_infracciones
        FROM EXAMEN E
        WHERE E.FechayHora > SYSDATE
        AND (
            SELECT COUNT(*) FROM ASISTENCIA 
              WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo
        ) > p_ratio * (
            SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes 
                  WHERE Examen_FechayHora = E.FechayHora
            )
        );

        RETURN (v_infracciones = 0);
    END VOCAL_RATIO;

END PK_OCUPACION;
/


-- ============================================================================
-- SEGURIDAD: Roles y permisos
-- ============================================================================

GRANT CREATE SEQUENCE TO PAU;

BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ESTUDIANTE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_VOCAL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ACCESO'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE ROLE ROL_ESTUDIANTE;
CREATE ROLE ROL_VOCAL;
GRANT CREATE SESSION TO ROL_ESTUDIANTE;
GRANT CREATE SESSION TO ROL_VOCAL;

-- Paquete PK_SEGURIDAD_PAU
CREATE OR REPLACE PACKAGE PK_SEGURIDAD_PAU AS
    PROCEDURE PR_CREA_ESTUDIANTE(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2);
    PROCEDURE PR_CREA_VOCAL(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2);
END PK_SEGURIDAD_PAU;
/

CREATE OR REPLACE PACKAGE BODY PK_SEGURIDAD_PAU AS

    PROCEDURE PR_CREA_ESTUDIANTE(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM ESTUDIANTE WHERE DNI = p_dni;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'El estudiante con DNI ' || p_dni || ' no existe.');
        END IF;

        p_usuario := 'EST_' || p_dni;
        p_password := DBMS_RANDOM.STRING('X', 10);

        EXECUTE IMMEDIATE 'CREATE USER ' || p_usuario || 
            ' IDENTIFIED BY "' || p_password || '" DEFAULT TABLESPACE TS_PAU';
        EXECUTE IMMEDIATE 'GRANT ROL_ESTUDIANTE TO ' || p_usuario;

        UPDATE ESTUDIANTE SET Usuario_BD = p_usuario WHERE DNI = p_dni;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END PR_CREA_ESTUDIANTE;

    PROCEDURE PR_CREA_VOCAL(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2
    ) AS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM VOCAL WHERE DNI = p_dni;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El vocal con DNI ' || p_dni || ' no existe.');
        END IF;

        p_usuario := 'VOC_' || p_dni;
        p_password := DBMS_RANDOM.STRING('X', 10);

        EXECUTE IMMEDIATE 'CREATE USER ' || p_usuario || 
            ' IDENTIFIED BY "' || p_password || '" DEFAULT TABLESPACE TS_PAU';
        EXECUTE IMMEDIATE 'GRANT ROL_VOCAL TO ' || p_usuario;

        UPDATE VOCAL SET Usuario_BD = p_usuario WHERE DNI = p_dni;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END PR_CREA_VOCAL;

END PK_SEGURIDAD_PAU;
/


-- Trigger TR_BORRA_AULA
CREATE OR REPLACE TRIGGER TR_BORRA_AULA
BEFORE DELETE ON AULA
FOR EACH ROW
DECLARE
    v_examenes_invalidos NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_examenes_invalidos
    FROM EXAMEN
    WHERE Aula_Codigo = :OLD.Codigo
      AND FechayHora < (SYSDATE + 2); 

    IF v_examenes_invalidos > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 
          'Error: El aula tiene examenes realizados o en las proximas 48h.');
    ELSE
        DELETE FROM ASISTENCIA 
        WHERE Examen_FechayHora IN (
          SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        DELETE FROM EXAMEN_MATERIA 
        WHERE Examen_FechayHora IN (
          SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        DELETE FROM EXAMEN_VOCAL_Vigilantes 
        WHERE Examen_FechayHora IN (
          SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        DELETE FROM EXAMEN 
        WHERE Aula_Codigo = :OLD.Codigo;
    END IF;
END TR_BORRA_AULA;
/


-- Procedimiento DESPISTE
CREATE OR REPLACE PROCEDURE DESPISTE(
    p_dni VARCHAR2, p_examen_fecha DATE, 
    p_aula_nueva VARCHAR2, p_sede_nueva VARCHAR2
) AS
    v_primera_hora DATE;
    v_aula_libre VARCHAR2(20);
BEGIN
    SELECT MIN(Examen_FechayHora) INTO v_primera_hora
    FROM ASISTENCIA
    WHERE Estudiante_DNI = p_dni 
      AND TRUNC(Examen_FechayHora) = TRUNC(p_examen_fecha);

    IF v_primera_hora IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'No se encontraron examenes para esa fecha.');
    END IF;

    IF NOT (v_primera_hora BETWEEN SYSDATE AND (SYSDATE + 1/24)) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Fuera de ventana de reubicacion (1h).');
    END IF;

    UPDATE ASISTENCIA
    SET Aula_Codigo = p_aula_nueva, Sede_Codigo = p_sede_nueva
    WHERE Estudiante_DNI = p_dni AND Examen_FechayHora = v_primera_hora;

    FOR rec IN (
        SELECT Examen_FechayHora, Materia_Codigo
        FROM ASISTENCIA
        WHERE Estudiante_DNI = p_dni 
          AND TRUNC(Examen_FechayHora) = TRUNC(p_examen_fecha)
          AND Examen_FechayHora > v_primera_hora
    ) LOOP
        BEGIN
            SELECT A.Codigo INTO v_aula_libre
            FROM AULA A
            WHERE A.Sede_Codigo = p_sede_nueva
              AND A.Capacidad_Examen > (
                  SELECT COUNT(*) 
                  FROM ASISTENCIA AST 
                  WHERE AST.Aula_Codigo = A.Codigo 
                    AND AST.Examen_FechayHora = rec.Examen_FechayHora
              )
            AND ROWNUM = 1;

            UPDATE ASISTENCIA
            SET Aula_Codigo = v_aula_libre, Sede_Codigo = p_sede_nueva
            WHERE Estudiante_DNI = p_dni 
              AND Examen_FechayHora = rec.Examen_FechayHora 
              AND Materia_Codigo = rec.Materia_Codigo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002, 
                  'No hay aulas libres en sede destino.');
        END;
    END LOOP;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END DESPISTE;
/


-- Procedimiento MIGRAR_CENTRO
CREATE OR REPLACE PROCEDURE MIGRAR_CENTRO(
    p_centro VARCHAR2, p_sede_origen VARCHAR2, p_sede_destino VARCHAR2
) AS
    v_aula_libre VARCHAR2(20);
BEGIN
    FOR rec_asistencia IN (
        SELECT AST.Estudiante_DNI, AST.Examen_FechayHora, AST.Materia_Codigo
        FROM ASISTENCIA AST
        JOIN ESTUDIANTE E ON AST.Estudiante_DNI = E.DNI
        WHERE E.Centro_Codigo = p_centro
          AND AST.Sede_Codigo = p_sede_origen
    ) LOOP
        BEGIN
            SELECT A.Codigo INTO v_aula_libre
            FROM AULA A
            WHERE A.Sede_Codigo = p_sede_destino
              AND A.Capacidad_Examen > (
                  SELECT COUNT(*) 
                  FROM ASISTENCIA AST_SUB
                  WHERE AST_SUB.Aula_Codigo = A.Codigo 
                    AND AST_SUB.Examen_FechayHora = rec_asistencia.Examen_FechayHora
              )
            AND ROWNUM = 1;

            UPDATE ASISTENCIA
            SET Sede_Codigo = p_sede_destino, Aula_Codigo = v_aula_libre
            WHERE Estudiante_DNI = rec_asistencia.Estudiante_DNI 
              AND Examen_FechayHora = rec_asistencia.Examen_FechayHora
              AND Materia_Codigo = rec_asistencia.Materia_Codigo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003, 
                  'Error de migracion: Sin capacidad en sede destino.');
        END;
    END LOOP;
END MIGRAR_CENTRO;
/


-- Trigger TR_MIGRAR_CENTRO
CREATE OR REPLACE TRIGGER TR_MIGRAR_CENTRO
AFTER UPDATE OF Sede_Codigo ON CENTRO
FOR EACH ROW
BEGIN
    IF :OLD.Sede_Codigo IS NOT NULL AND :OLD.Sede_Codigo <> :NEW.Sede_Codigo THEN
        MIGRAR_CENTRO(:NEW.Codigo, :OLD.Sede_Codigo, :NEW.Sede_Codigo);
    END IF;
END TR_MIGRAR_CENTRO;
/


-- ============================================================================
-- VISTAS DE SEGURIDAD
-- ============================================================================

CREATE OR REPLACE VIEW V_MI_ASIGNACION AS
SELECT a.Materia_Codigo, a.Examen_FechayHora, a.Sede_Codigo, a.Aula_Codigo
FROM ASISTENCIA a
JOIN ESTUDIANTE e ON a.Estudiante_DNI = e.DNI
WHERE e.Usuario_BD = USER;

CREATE OR REPLACE VIEW V_MIS_DATOS AS
SELECT DNI, Nombre, Apellidos, Telefono, Correo, Centro_Codigo 
FROM ESTUDIANTE
WHERE Usuario_BD = USER;

CREATE OR REPLACE VIEW V_MI_VIGILANCIA AS
SELECT e.FechayHora, e.Aula_Codigo, 'PRINCIPAL' as Rol_Vigilancia,
       e.Num_Estudiantes_Presentes
FROM EXAMEN e
JOIN VOCAL v ON e.Vocal_DNI = v.DNI
WHERE v.Usuario_BD = USER
UNION
SELECT ev.Examen_FechayHora, ex.Aula_Codigo, 'VIGILANTE', NULL
FROM EXAMEN_VOCAL_Vigilantes ev
JOIN EXAMEN ex ON ev.Examen_FechayHora = ex.FechayHora
JOIN VOCAL v ON ev.Vocal_DNI = v.DNI
WHERE v.Usuario_BD = USER;

CREATE OR REPLACE VIEW V_MI_SEDE_GESTION AS
SELECT s.Codigo, s.Nombre, s.Tipo
FROM SEDE s
JOIN VOCAL v ON s.Vocal_Responsable_DNI = v.DNI
WHERE v.Usuario_BD = USER;

CREATE OR REPLACE VIEW V_ASIGNACION_GLOBAL AS
SELECT c.Nombre AS Centro_Nombre,
       e.Nombre || ' ' || e.Apellidos AS Estudiante,
       s.Nombre AS Sede_Nombre, a.Aula_Codigo, a.Examen_FechayHora
FROM ASISTENCIA a
JOIN ESTUDIANTE e ON a.Estudiante_DNI = e.DNI
JOIN CENTRO c ON e.Centro_Codigo = c.Codigo
JOIN SEDE s ON a.Sede_Codigo = s.Codigo;

CREATE ROLE ROL_ACCESO;
GRANT CREATE SESSION TO ROL_ACCESO;

-- Permisos a roles
GRANT SELECT ON V_OCUPACION_ASIGNADA TO ROL_ESTUDIANTE;
GRANT SELECT ON V_MI_ASIGNACION TO ROL_ESTUDIANTE;
GRANT SELECT ON V_MIS_DATOS TO ROL_ESTUDIANTE;

GRANT SELECT ON EXAMEN TO ROL_VOCAL;
GRANT UPDATE (Num_Estudiantes_Presentes) ON EXAMEN TO ROL_VOCAL;
GRANT SELECT ON V_MI_VIGILANCIA TO ROL_VOCAL;
GRANT UPDATE (Asiste) ON ASISTENCIA TO ROL_VOCAL;
GRANT SELECT ON V_MI_SEDE_GESTION TO ROL_VOCAL;
GRANT SELECT, UPDATE (Nombre, Tipo) ON SEDE TO ROL_VOCAL;

GRANT SELECT ON V_ASIGNACION_GLOBAL TO ROL_ACCESO;
GRANT EXECUTE ON PK_ASIGNA TO ROL_ACCESO;
GRANT SELECT ON V_OCUPACION_ASIGNADA TO ROL_ACCESO;
GRANT SELECT ON V_OCUPACION TO ROL_ACCESO;
GRANT SELECT ON V_VIGILANTES TO ROL_ACCESO;
GRANT UPDATE (Vocal_Responsable_DNI, Vocal_Secretario_DNI) ON SEDE TO ROL_ACCESO;


-- ============================================================================
-- SEGURIDAD: Politicas, auditoria, restricciones
-- ============================================================================

-- Politica de contraseñas
ALTER PROFILE DEFAULT LIMIT
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LIFE_TIME    30
  PASSWORD_GRACE_TIME   5
  PASSWORD_LOCK_TIME    1;

-- Validacion DNI (NOVALIDATE para datos existentes)
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ESTUDIANTE DROP CONSTRAINT CHK_ESTUDIANTE_DNI_FORMAT'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE VOCAL DROP CONSTRAINT CHK_VOCAL_DNI_FORMAT'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
ALTER TABLE ESTUDIANTE ADD CONSTRAINT CHK_ESTUDIANTE_DNI_FORMAT
  CHECK (REGEXP_LIKE(DNI, '^[0-9]{8}[A-Z]$')) NOVALIDATE;

ALTER TABLE VOCAL ADD CONSTRAINT CHK_VOCAL_DNI_FORMAT
  CHECK (REGEXP_LIKE(DNI, '^[0-9]{8}[A-Z]$')) NOVALIDATE;

-- VPD para estudiantes
CREATE OR REPLACE FUNCTION FN_ESTUDIANTE_VPD(
  p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 AS
BEGIN
  IF SYS_CONTEXT('USERENV', 'SESSION_USER') = 'PAU' THEN
    RETURN NULL;
  END IF;
  RETURN 'Usuario_BD = USER';
END;
/

BEGIN
  DBMS_RLS.DROP_POLICY(
    object_schema => 'PAU',
    object_name   => 'ESTUDIANTE',
    policy_name   => 'POL_ESTUDIANTE_VPD'
  );
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema => 'PAU',
    object_name   => 'ESTUDIANTE',
    policy_name   => 'POL_ESTUDIANTE_VPD',
    function_schema => 'PAU',
    policy_function => 'FN_ESTUDIANTE_VPD'
  );
END;
/

-- Auditoria unificada (Oracle 23ai)
BEGIN
  EXECUTE IMMEDIATE 'NOAUDIT POLICY audit_asistencia_updates';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP AUDIT POLICY audit_asistencia_updates';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE AUDIT POLICY audit_asistencia_updates
  ACTIONS UPDATE ON PAU.ASISTENCIA;
AUDIT POLICY audit_asistencia_updates;


-- ============================================================================
-- PARTE 4: RUBRICA - RESTRICCIONES ADICIONALES
-- ============================================================================

-- Restricciones semanticas
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE EXAMEN DROP CONSTRAINT CHK_EXAMEN_NUM_EST'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA DROP CONSTRAINT CHK_ASISTENCIA_ASISTE_VALUES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA DROP CONSTRAINT CHK_ASISTENCIA_ENTREGA_VALUES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE CENTRO DROP CONSTRAINT CHK_CENTRO_NOMBRE_NOT_NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
ALTER TABLE EXAMEN ADD CONSTRAINT CHK_EXAMEN_NUM_EST 
  CHECK (Num_Estudiantes_Presentes >= 0);

ALTER TABLE ASISTENCIA ADD CONSTRAINT CHK_ASISTENCIA_ASISTE_VALUES 
  CHECK (Asiste IN ('S', 'N'));

ALTER TABLE ASISTENCIA ADD CONSTRAINT CHK_ASISTENCIA_ENTREGA_VALUES 
  CHECK (Entrega IN ('S', 'N'));

ALTER TABLE CENTRO ADD CONSTRAINT CHK_CENTRO_NOMBRE_NOT_NULL 
  CHECK (Nombre IS NOT NULL);


-- ============================================================================
-- COMPROBACIONES FINALES
-- ============================================================================

SELECT 'TABLAS' AS tipo, COUNT(*) AS total FROM user_tables
UNION ALL
SELECT 'INDICES', COUNT(*) FROM user_indexes
UNION ALL
SELECT 'VISTAS', COUNT(*) FROM user_views
UNION ALL
SELECT 'PROCEDIMIENTOS', COUNT(*) FROM user_objects WHERE object_type = 'PROCEDURE'
UNION ALL
SELECT 'PAQUETES', COUNT(*) FROM user_objects WHERE object_type = 'PACKAGE'
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM user_triggers;

SELECT 'VOCALES' AS tabla, COUNT(*) AS total FROM VOCAL
UNION ALL
SELECT 'MATERIAS', COUNT(*) FROM MATERIA
UNION ALL
SELECT 'SEDES', COUNT(*) FROM SEDE
UNION ALL
SELECT 'ESTUDIANTES', COUNT(*) FROM ESTUDIANTE
UNION ALL
SELECT 'CENTROS', COUNT(*) FROM CENTRO
UNION ALL
SELECT 'MATRICULAS', COUNT(*) FROM ESTUDIANTE_MATERIA;

PROMPT ========================================
PROMPT SCRIPT DE ENTREGA COMPLETADO
PROMPT ========================================
