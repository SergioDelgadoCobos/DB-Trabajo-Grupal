-- EJECUTADO DESDE SYS
-- Creamos el usuario PAU
CREATE USER PAU IDENTIFIED BY pau;

-- Damos permisos de administrador de BD
GRANT DBA TO PAU;

-- Crear tablespace para datos
CREATE TABLESPACE TS_PAU 
DATAFILE 'ts_pau.dbf' SIZE 100M 
AUTOEXTEND ON;

-- Asignamos el tablespace a pau
ALTER USER PAU DEFAULT TABLESPACE TS_PAU;

-- Crear tablespace para �ndices (50 MB)
CREATE TABLESPACE TS_INDICES 
DATAFILE 'ts_indices.dbf' SIZE 50M;

-- Asignar cuotas
ALTER USER PAU QUOTA UNLIMITED ON TS_PAU;
ALTER USER PAU QUOTA UNLIMITED ON TS_INDICES;

-- Comprobar que existen los tablespaces creados
SELECT tablespace_name, status, contents 
FROM dba_tablespaces 
WHERE tablespace_name IN ('TS_PAU', 'TS_INDICES');

-- Comprobar el tablespace por defecto de PAU
SELECT username, default_tablespace, account_status 
FROM dba_users 
WHERE username = 'PAU';

-- Comprobar los datafiles asociados a los tablespaces
SELECT file_name, tablespace_name, bytes/1024/1024 AS MB 
FROM dba_data_files 
WHERE tablespace_name IN ('TS_PAU', 'TS_INDICES');

-- Directorio
create or replace directory directorio_ext as 'C:\app\alumnos\admin\orcl\dpdump';
grant read, write on directory directorio_ext to PAU;

-- CAMBIAMOS A USUARIO PAU

-- DROP TABLES
BEGIN
   FOR rec IN (SELECT table_name FROM user_tables) LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS PURGE';
   END LOOP;
END;
/

-- Creamos tablas
CREATE TABLE ANE 
    ( 
     DNI        VARCHAR2 (20)  NOT NULL , 
     Descabezar CHAR (1) , 
     AulaAparte CHAR (1) 
    ) 
;

ALTER TABLE ANE 
    ADD CONSTRAINT ANE_PK PRIMARY KEY ( DNI ) ;


CREATE TABLE ASISTENCIA 
    ( 
     Asiste            CHAR (1)  NOT NULL , 
     Entrega           CHAR (1) , 
     Examen_FechayHora DATE  NOT NULL , 
     Estudiante_DNI    VARCHAR2 (20)  NOT NULL , 
     Materia_Codigo    VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE ASISTENCIA 
    ADD CONSTRAINT ASISTENCIA_PK PRIMARY KEY ( Examen_FechayHora, Estudiante_DNI, Materia_Codigo ) ;


CREATE TABLE AULA ( 
     Codigo           VARCHAR2 (20)  NOT NULL , 
     Capacidad        NUMBER  NOT NULL , 
     Capacidad_Examen NUMBER  NOT NULL , 
     Descripcion      VARCHAR2 (500) , 
     Sede_Codigo      VARCHAR2 (20)  NOT NULL,

    -- Puntos extras
     CONSTRAINT CHK_AULA_CAPACIDAD CHECK (Capacidad > 0),
     CONSTRAINT CHK_AULA_CAP_EXAMEN CHECK (Capacidad_Examen > 0 AND Capacidad_Examen <= Capacidad)
) ;

ALTER TABLE AULA 
    ADD CONSTRAINT AULA_PK PRIMARY KEY ( Codigo ) ;


CREATE TABLE CENTRO 
    ( 
     Codigo      VARCHAR2 (20)  NOT NULL , 
     Nombre      VARCHAR2 (100)  NOT NULL , 
     Direccion   VARCHAR2 (200) , 
     Poblacion   VARCHAR2 (200) , 
     Sede_Codigo VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE CENTRO 
    ADD CONSTRAINT CENTRO_PK PRIMARY KEY ( Codigo ) ;


CREATE TABLE ESTUDIANTE 
    ( 
     DNI           VARCHAR2 (20)  NOT NULL , 
     Nombre        VARCHAR2 (50)  NOT NULL , 
     Apellidos     VARCHAR2 (100)  NOT NULL , 
     Telefono      VARCHAR2 (50)  NOT NULL , 
     Correo        VARCHAR2 (150) , 
     Centro_Codigo VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE ESTUDIANTE 
    ADD CONSTRAINT ESTUDIANTE_PK PRIMARY KEY ( DNI ) ;


CREATE TABLE ESTUDIANTE_MATERIA 
    ( 
     Estudiante_DNI VARCHAR2 (20)  NOT NULL , 
     Materia_Codigo VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE ESTUDIANTE_MATERIA 
    ADD CONSTRAINT ESTUDIANTE_MATERIA_PK PRIMARY KEY ( Estudiante_DNI, Materia_Codigo ) ;


CREATE TABLE EXAMEN 
    ( 
     FechayHora   DATE  NOT NULL , 
     Aula_Codigo  VARCHAR2 (20)  NOT NULL , 
     Vocal_DNI    VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE EXAMEN 
    ADD CONSTRAINT EXAMEN_PK PRIMARY KEY ( FechayHora ) ;


CREATE TABLE EXAMEN_MATERIA 
    ( 
     Examen_FechayHora DATE  NOT NULL , 
     Materia_Codigo    VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE EXAMEN_MATERIA 
    ADD CONSTRAINT EXAMEN_MATERIA_PK PRIMARY KEY ( Examen_FechayHora, Materia_Codigo ) ;


CREATE TABLE EXAMEN_VOCAL_Vigilantes 
    ( 
     Examen_FechayHora DATE  NOT NULL , 
     Vocal_DNI         VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE EXAMEN_VOCAL_Vigilantes 
    ADD CONSTRAINT EXAMEN_VOCAL_VIGILANTES_PK PRIMARY KEY ( Examen_FechayHora, Vocal_DNI ) ;


CREATE TABLE MATERIA 
    ( 
     Codigo VARCHAR2 (20)  NOT NULL , 
     Nombre VARCHAR2 (100)  NOT NULL 
    ) 
;

ALTER TABLE MATERIA 
    ADD CONSTRAINT MATERIA_PK PRIMARY KEY ( Codigo ) ;


CREATE TABLE SEDE 
    ( 
     Codigo                 VARCHAR2 (20)  NOT NULL , 
     Nombre                 VARCHAR2 (100)  NOT NULL , 
     Tipo                   VARCHAR2 (100) , 
     Vocal_Secretario_DNI   VARCHAR2 (20)  NOT NULL , 
     Vocal_Responsable_DNI  VARCHAR2 (20)  NOT NULL 
    ) 
;

CREATE UNIQUE INDEX SEDE_UQ_VOCAL_RESP ON SEDE 
    ( 
     Vocal_Responsable_DNI ASC 
    ) 
;
CREATE UNIQUE INDEX SEDE_UQ_VOCAL_SEC ON SEDE 
    ( 
     Vocal_Secretario_DNI ASC 
    ) 
;

ALTER TABLE SEDE 
    ADD CONSTRAINT SEDE_PK PRIMARY KEY ( Codigo ) ;


CREATE TABLE VOCAL 
    ( 
     DNI            VARCHAR2 (20)  NOT NULL , 
     Nombre         VARCHAR2 (50)  NOT NULL , 
     Apellidos      VARCHAR2 (100)  NOT NULL , 
     Tipo           VARCHAR2 (100) , 
     Cargo          VARCHAR2 (100) , 
     Materia_Codigo VARCHAR2 (20) 
    ) 
;

ALTER TABLE VOCAL 
    ADD CONSTRAINT VOCAL_PK PRIMARY KEY ( DNI ) ;


ALTER TABLE ANE 
    ADD CONSTRAINT ANE_ESTUDIANTE_FK FOREIGN KEY ( DNI ) 
    REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ASISTENCIA 
    ADD CONSTRAINT ASISTENCIA_ESTUDIANTE_FK FOREIGN KEY ( Estudiante_DNI ) 
    REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ASISTENCIA 
    ADD CONSTRAINT ASISTENCIA_EXAMEN_FK FOREIGN KEY ( Examen_FechayHora ) 
    REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE ASISTENCIA 
    ADD CONSTRAINT ASISTENCIA_MATERIA_FK FOREIGN KEY ( Materia_Codigo ) 
    REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE AULA 
    ADD CONSTRAINT AULA_SEDE_FK FOREIGN KEY ( Sede_Codigo ) 
    REFERENCES SEDE ( Codigo ) ;

ALTER TABLE CENTRO 
    ADD CONSTRAINT CENTRO_SEDE_FK FOREIGN KEY ( Sede_Codigo ) 
    REFERENCES SEDE ( Codigo ) ;

ALTER TABLE ESTUDIANTE 
    ADD CONSTRAINT ESTUDIANTE_CENTRO_FK FOREIGN KEY ( Centro_Codigo ) 
    REFERENCES CENTRO ( Codigo ) ;

ALTER TABLE ESTUDIANTE_MATERIA 
    ADD CONSTRAINT EM_ESTUDIANTE_FK FOREIGN KEY ( Estudiante_DNI ) 
    REFERENCES ESTUDIANTE ( DNI ) ;

ALTER TABLE ESTUDIANTE_MATERIA 
    ADD CONSTRAINT ESTUDIANTE_MATERIA_MATERIA_FK FOREIGN KEY ( Materia_Codigo ) 
    REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE EXAMEN 
    ADD CONSTRAINT EXAMEN_AULA_FK FOREIGN KEY ( Aula_Codigo ) 
    REFERENCES AULA ( Codigo ) ;

ALTER TABLE EXAMEN_MATERIA 
    ADD CONSTRAINT EXAMEN_MATERIA_EXAMEN_FK FOREIGN KEY ( Examen_FechayHora ) 
    REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE EXAMEN_MATERIA 
    ADD CONSTRAINT EXAMEN_MATERIA_MATERIA_FK FOREIGN KEY ( Materia_Codigo ) 
    REFERENCES MATERIA ( Codigo ) ;

ALTER TABLE EXAMEN 
    ADD CONSTRAINT EXAMEN_VOCAL_FK FOREIGN KEY ( Vocal_DNI ) 
    REFERENCES VOCAL ( DNI ) ;

ALTER TABLE EXAMEN_VOCAL_Vigilantes 
    ADD CONSTRAINT EVV_EXAMEN_FK FOREIGN KEY ( Examen_FechayHora ) 
    REFERENCES EXAMEN ( FechayHora ) ;

ALTER TABLE EXAMEN_VOCAL_Vigilantes 
    ADD CONSTRAINT EVV_VOCAL_FK FOREIGN KEY ( Vocal_DNI ) 
    REFERENCES VOCAL ( DNI ) ;

ALTER TABLE SEDE 
    ADD CONSTRAINT SEDE_VOCAL_RESP_FK FOREIGN KEY ( Vocal_Responsable_DNI ) 
    REFERENCES VOCAL ( DNI ) ;

ALTER TABLE SEDE 
    ADD CONSTRAINT SEDE_VOCAL_SEC_FK FOREIGN KEY ( Vocal_Secretario_DNI ) 
    REFERENCES VOCAL ( DNI ) ;

ALTER TABLE VOCAL 
    ADD CONSTRAINT Vocal_Materia_FK FOREIGN KEY ( Materia_Codigo ) 
    REFERENCES MATERIA ( Codigo ) ;

-- Estudiantes_EXT
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
    LOCATION ('datos-estudiantes-PAU.csv')
);

-- crear vista
create or replace view v_estudiantes as
SELECT dni, nombre, apellido1 ||' '||apellido2 apellidos,
 telefono,
 substr(nombre,1,1)||apellido1||substr(dni,6,3) ||'@uncorreo.es' correo,
 centro, detalle_materias
FROM estudiantes_ext
 where dni is not null;
-- salen 158

-- procedimientos matriculas
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
END PR_MATRICULA_ESTUDIANTES;
/

-- procedimientos aulas

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
END PR_RELLENA_AULAS;
/

CREATE OR REPLACE PROCEDURE PR_BORRA_AULA_SEDE(
  PCODIGOSEDE IN SEDE.Codigo%TYPE
) AS
BEGIN
  DELETE FROM AULA WHERE Sede_Codigo = PCODIGOSEDE;
  COMMIT;
END PR_BORRA_AULA_SEDE;
/

CREATE OR REPLACE PROCEDURE PR_BORRA_AULAS AS
BEGIN
  FOR s IN (SELECT Codigo FROM SEDE) LOOP
    PR_BORRA_AULA_SEDE(s.Codigo);
  END LOOP;
END PR_BORRA_AULAS;
/

-- Puntos extras
-- Tabla para registrar cambios en la asistencia (Auditoría)
CREATE TABLE LOG_ASISTENCIA (
    Usuario_Modifica VARCHAR2(50),
    Fecha_Cambio     DATE,
    DNI_Estudiante   VARCHAR2(20),
    Materia          VARCHAR2(20),
    Accion           VARCHAR2(20) -- INSERT, UPDATE, DELETE
);

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