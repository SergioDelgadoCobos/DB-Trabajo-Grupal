-- ============================================================================
-- BASES DE DATOS II -- TRABAJO GRUPO PAU
-- PRIMERA ENTREGA: ESQUEMA Y DATOS
-- Universidad de Malaga -- ETSI Informatica -- 2025-26
-- ============================================================================
-- INSTRUCCIONES:
--   1. Conectarse como SYS a la PDB
--   2. Copiar datos-estudiantes-pau.csv al directorio dpdump de Oracle (ej: C:\app\alumnos\admin\orcl\dpdump)
--   3. Ejecutar este script completo
-- ============================================================================

-- EJECUTADO DESDE SYS

-- Creamos tablespaces (si no existen)
CREATE TABLESPACE TS_PAU 
DATAFILE 'ts_pau.dbf' SIZE 100M 
AUTOEXTEND ON;

CREATE TABLESPACE TS_INDICES 
DATAFILE 'ts_indices.dbf' SIZE 50M;

-- Crear usuario PAU
CREATE USER PAU IDENTIFIED BY pau DEFAULT TABLESPACE TS_PAU 
  QUOTA UNLIMITED ON TS_PAU QUOTA UNLIMITED ON TS_INDICES;

-- Permisos especificos (evitamos GRANT DBA)
GRANT CONNECT, RESOURCE TO PAU;
GRANT CREATE VIEW, CREATE MATERIALIZED VIEW, CREATE PROCEDURE, 
      CREATE SEQUENCE, CREATE TRIGGER, CREATE SYNONYM, CREATE PUBLIC SYNONYM TO PAU;

-- Directorio para tabla externa
CREATE OR REPLACE DIRECTORY directorio_ext AS 'C:\app\alumnos\admin\orcl\dpdump';
GRANT READ, WRITE ON DIRECTORY directorio_ext TO PAU;

-- Permisos adicionales
GRANT EXECUTE ON SYS.DBMS_RANDOM TO PAU;
GRANT EXECUTE ON SYS.DBMS_RLS TO PAU;


-- ============================================================================
-- CAMBIAMOS A USUARIO PAU
-- ============================================================================
ALTER SESSION SET CURRENT_SCHEMA = PAU;

-- Drop objetos existentes (orden correcto para re-ejecucion)
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
-- Puntos extras: restricciones CHECK (como ALTER TABLE para evitar SP2-0734)
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE AULA DROP CONSTRAINT CHK_AULA_CAPACIDAD'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE AULA DROP CONSTRAINT CHK_AULA_CAP_EXAMEN'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
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

-- VOCALES desde Vocales.xlsx (197 registros)
@@Vocales_Insert.sql

-- MATERIAS desde Materias.csv
INSERT ALL
INTO MATERIA (Codigo, Nombre) VALUES ('AleAcc', 'Aleman (Fase de Acceso)')
INTO MATERIA (Codigo, Nombre) VALUES ('AleAd', 'Aleman (Fase de Admision)')
INTO MATERIA (Codigo, Nombre) VALUES ('Art', 'Artes Escenicas')
INTO MATERIA (Codigo, Nombre) VALUES ('Bio', 'Biologia')
INTO MATERIA (Codigo, Nombre) VALUES ('Cul', 'Cultura Audiovisual II')
INTO MATERIA (Codigo, Nombre) VALUES ('Dib', 'Dibujo Tecnico II')
INTO MATERIA (Codigo, Nombre) VALUES ('Dis', 'Diseno')
INTO MATERIA (Codigo, Nombre) VALUES ('Eco', 'Economia de la Empresa')
INTO MATERIA (Codigo, Nombre) VALUES ('Fis', 'Fisica')
INTO MATERIA (Codigo, Nombre) VALUES ('FraAcc', 'Frances (Fase de Acceso)')
INTO MATERIA (Codigo, Nombre) VALUES ('FraAd', 'Frances (Fase de Admision)')
INTO MATERIA (Codigo, Nombre) VALUES ('Fun', 'Fundamentos del Arte II')
INTO MATERIA (Codigo, Nombre) VALUES ('Geog', 'Geografia')
INTO MATERIA (Codigo, Nombre) VALUES ('Geol', 'Geologia')
INTO MATERIA (Codigo, Nombre) VALUES ('Gri', 'Griego II')
INTO MATERIA (Codigo, Nombre) VALUES ('HisE', 'Historia de Espa?a')
INTO MATERIA (Codigo, Nombre) VALUES ('HisF', 'Historia de la Filosofia')
INTO MATERIA (Codigo, Nombre) VALUES ('HisA', 'Historia del Arte')
INTO MATERIA (Codigo, Nombre) VALUES ('IngAcc', 'Ingles (Fase de Acceso)')
INTO MATERIA (Codigo, Nombre) VALUES ('IngAd', 'Ingles (Fase de Admision)')
INTO MATERIA (Codigo, Nombre) VALUES ('ItaAcc', 'Italiano (Fase de Acceso)')
INTO MATERIA (Codigo, Nombre) VALUES ('ItaAd', 'Italiano (Fase de Admision)')
INTO MATERIA (Codigo, Nombre) VALUES ('Lat', 'Latin II')
INTO MATERIA (Codigo, Nombre) VALUES ('Len', 'Lengua Castellana y Literatura')
INTO MATERIA (Codigo, Nombre) VALUES ('Mat', 'Matematicas II')
INTO MATERIA (Codigo, Nombre) VALUES ('MatApl', 'Matematicas Aplicadas a las CCSS')
INTO MATERIA (Codigo, Nombre) VALUES ('PorAcc', 'Portugues (Fase de Acceso)')
INTO MATERIA (Codigo, Nombre) VALUES ('PorAd', 'Portugues (Fase de Admision)')
INTO MATERIA (Codigo, Nombre) VALUES ('Qui', 'Quimica')
SELECT * FROM DUAL;

COMMIT;

-- SEDES desde Sedes.xlsx
INSERT ALL
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('1', 'Facultad de Medicina', 'UNIVERSIDAD', '95115697E', '37106003Z')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('2', 'Complejo de EE.Sociales y Comercio', 'UNIVERSIDAD', '83582041G', '94949702N')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('3', 'Escuela de Ingenierias Industriales', 'UNIVERSIDAD', '02758528E', '78541977C')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('4', 'Facultad de Derecho', 'UNIVERSIDAD', '69575980A', '68375332C')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('5', 'Aulario Gerald Brenan', 'UNIVERSIDAD', '37106003M', '36605742L')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('6', 'E.T.S.Ing. de Telecomunicacion/ E.T.S. Ing. Informatica', 'UNIVERSIDAD', '94949702C', '95780079C')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('7', 'Fac. CC. de la Educacion', 'UNIVERSIDAD', '78541976B', '03173087M')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('8', 'Fac. de Filosofia y Letras', 'UNIVERSIDAD', '68375332L', '23065434Z')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('9', 'Aulario Severo Ochoa', 'UNIVERSIDAD', '36605742R', '39569835F')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('10', 'I.E.S. Reyes Catolicos', 'INSTITUTO', '95780079G', '54185897A')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('11', 'I.E.S. Arroyo de la Miel', 'INSTITUTO', '03173087N', '02670198N')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('12', 'I.E.S. Pintor Jose Maria Fernandez', 'INSTITUTO', '23065434S', '33242149T')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('13', 'I.E.S. Fuengirola', 'INSTITUTO', '39569834C', '89402973C')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('14', 'I.E.S. Rio Verde', 'INSTITUTO', '54185897C', '36331685E')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('15', 'I.E.S. Monterroso', 'INSTITUTO', '02670198A', '44690032R')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('16', 'I.E.S. Dr. Rodriguez Delgado', 'INSTITUTO', '95115697R', '47273167C')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('17', 'I.E.S. Valle del Azahar', 'INSTITUTO', '83582041Z', '34571357L')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('18', 'Facultad CC.de la Comunicacion y Facultad de Turismo', 'UNIVERSIDAD', '02758528U', '94795937T')
INTO SEDE (Codigo, Nombre, Tipo, Vocal_Responsable_DNI, Vocal_Secretario_DNI) VALUES ('19', 'I.E.S. Maria Zambrano', 'INSTITUTO', '69575980V', '20146337C')
SELECT * FROM DUAL;

COMMIT;


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


-- ============================================================================
-- PUNTOS EXTRAS: AUDITORIA
-- ============================================================================

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
PROMPT PRIMERA ENTREGA COMPLETADA
PROMPT ========================================
