CREATE TABLE ActionLog (
    Id          INTEGER  PRIMARY KEY AUTOINCREMENT
                         NOT NULL
                         UNIQUE,
    UserId               REFERENCES AspNetUsers (Id) ON DELETE NO ACTION
                         NOT NULL,
    DateTimeUTC DATETIME NOT NULL,
    Message     TEXT,
    ActionType  INTEGER  NOT NULL
);


PRAGMA foreign_keys = 0;

CREATE TABLE sqlitestudio_temp_table AS SELECT *
                                          FROM ActionLog;

DROP TABLE ActionLog;

CREATE TABLE ActionLog (
    Id          INTEGER  PRIMARY KEY AUTOINCREMENT
                         NOT NULL
                         UNIQUE,
    UserId               REFERENCES AspNetUsers (Id) ON DELETE NO ACTION
                         NOT NULL,
    DateTimeUTC DATETIME NOT NULL,
    Message     TEXT,
    ActionType  INTEGER  NOT NULL,
    Successful  BOOLEAN  NOT NULL
);

INSERT INTO ActionLog (
                          Id,
                          UserId,
                          DateTimeUTC,
                          Message,
                          ActionType
                      )
                      SELECT Id,
                             UserId,
                             DateTimeUTC,
                             Message,
                             ActionType
                        FROM sqlitestudio_temp_table;

DROP TABLE sqlitestudio_temp_table;

PRAGMA foreign_keys = 1;