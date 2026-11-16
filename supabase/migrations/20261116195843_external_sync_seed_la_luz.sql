-- Datos iniciales de sincronización con NW Scheduler para la congregación La Luz,
-- sacados de sus exportaciones CSV (Territorios, Personas y Asignaciones de
-- Territorio) del 16/11/2026 y emparejados con los datos de la app.
--
-- - Territorios: AVnnn -> A/AV/n, LUnnn -> L/LUA/n, RUnnn -> R/RU/n.
-- - Hermanos: external_name es el DisplayName exacto de NW Scheduler (con sus
--   espacios). external_id (PersonID) queda vacío para quienes solo aparecen en el
--   historial de asignaciones y no en la exportación de Personas.
-- - Sin correspondencia en NW Scheduler (quedan sin external_name): Conchita
--   Alonso, Dana Álvarez, Erik Maltsev, Manuel Costa, Paquita Díaz, Patrick
--   Kramer y los desactivados Ainhoa Barrufet, Eli de Ramos, Encarnita Millán,
--   Lucas Ledesma y Marcos Yagüe.
--
-- No hace nada si la congregación no existe (p. ej. en local).

do $$
declare
  v_congregation_id uuid;
begin
  select id into v_congregation_id
    from public.congregations
   where name = 'La Luz';

  if v_congregation_id is null then
    raise notice 'Congregación La Luz no encontrada; se omite la carga de external ids.';
    return;
  end if;

  -- Territorios: código de la app -> TerritoryID de NW Scheduler.
  update public.territories t
     set external_id = v.external_id
    from (values
      ('AV001', '6533450'),
      ('AV002', '7434474'),
      ('AV003', '6173537'),
      ('AV004', '3255988'),
      ('AV005', '7403278'),
      ('AV006', '1895553'),
      ('AV007', '3031086'),
      ('AV008', '5002861'),
      ('AV009', '1726438'),
      ('AV010', '3627565'),
      ('AV011', '2773565'),
      ('AV012', '7038820'),
      ('AV013', '7605263'),
      ('AV014', '6465052'),
      ('AV015', '3695588'),
      ('AV016', '9293711'),
      ('AV017', '6726488'),
      ('AV018', '7564498'),
      ('AV019', '7195820'),
      ('AV020', '3805472'),
      ('AV021', '6622086'),
      ('AV022', '3255656'),
      ('AV023', '2829429'),
      ('AV024', '4403280'),
      ('AV025', '3099414'),
      ('AV026', '3241915'),
      ('AV027', '5778217'),
      ('AV028', '7285068'),
      ('AV029', '6667576'),
      ('AV030', '3687461'),
      ('AV031', '9542030'),
      ('AV032', '7522497'),
      ('AV033', '1169652'),
      ('AV034', '6857531'),
      ('AV035', '3752197'),
      ('AV036', '7822880'),
      ('AV037', '3544274'),
      ('AV038', '1317898'),
      ('AV039', '6295708'),
      ('AV040', '9012432'),
      ('AV041', '1614542'),
      ('AV042', '7638864'),
      ('AV043', '4440830'),
      ('AV044', '9016930'),
      ('AV045', '5583086'),
      ('AV046', '7080055'),
      ('AV047', '5733158'),
      ('AV048', '2659777'),
      ('AV049', '7545747'),
      ('AV050', '9347216'),
      ('AV051', '5419034'),
      ('AV052', '4740794'),
      ('AV053', '8845197'),
      ('AV054', '2115602'),
      ('AV055', '8125681'),
      ('AV056', '7868710'),
      ('AV057', '4726887'),
      ('AV058', '2763289'),
      ('AV059', '4808618'),
      ('AV060', '4825380'),
      ('AV061', '3662582'),
      ('AV062', '7392071'),
      ('AV063', '2712333'),
      ('AV064', '5584739'),
      ('AV065', '8275184'),
      ('AV066', '1855943'),
      ('AV067', '3219829'),
      ('AV068', '9700035'),
      ('AV069', '1171733'),
      ('AV070', '3090413'),
      ('AV071', '5900362'),
      ('AV072', '2602052'),
      ('AV073', '8396912'),
      ('AV074', '3477975'),
      ('AV075', '4764181'),
      ('AV076', '6077625'),
      ('AV077', '5898565'),
      ('AV078', '5273493'),
      ('AV079', '8057257'),
      ('AV080', '9850496'),
      ('AV081', '7012766'),
      ('AV082', '9060784'),
      ('AV083', '7028784'),
      ('AV084', '7668867'),
      ('AV085', '4701624'),
      ('AV086', '5516371'),
      ('AV087', '4874836'),
      ('AV088', '1380432'),
      ('AV089', '8704974'),
      ('AV090', '2761537'),
      ('AV091', '1089217'),
      ('AV092', '3609599'),
      ('AV093', '5734440'),
      ('AV094', '4309019'),
      ('AV095', '7743653'),
      ('AV096', '3239915'),
      ('AV097', '8887595'),
      ('AV098', '3541266'),
      ('AV099', '3906341'),
      ('AV100', '3036279'),
      ('AV101', '7476481'),
      ('AV102', '3295878'),
      ('AV103', '1090757'),
      ('AV104', '6482280'),
      ('AV105', '9728971'),
      ('AV106', '1517167'),
      ('AV107', '9472307'),
      ('AV108', '4116419'),
      ('AV109', '1157226'),
      ('AV110', '6957970'),
      ('AV111', '8066261'),
      ('AV112', '7839164'),
      ('AV113', '9802802'),
      ('AV114', '9725257'),
      ('LU001', '7169142'),
      ('LU002', '7152785'),
      ('LU003', '4046579'),
      ('LU004', '4616882'),
      ('LU005', '5436770'),
      ('LU006', '6108505'),
      ('LU007', '3587368'),
      ('RU001', '9879014'),
      ('RU002', '3258678'),
      ('RU003', '7787292'),
      ('RU004', '5119845'),
      ('RU005', '8382200')
    ) as v(code, external_id)
   where t.congregation_id = v_congregation_id
     and t.code = v.code;

  -- Hermanos: DisplayName exacto de NW Scheduler (con sus espacios) y PersonID si
  -- aparece en la exportación de Personas.
  update public.persons p
     set external_name = v.external_name,
         external_id = v.external_id
    from (values
      (33, '(García) Iglesias del Valle, Ainhoa', '260594457'), -- Ainhoa Iglesias
      (34, ' Cubillas Marín, Alberto', null), -- Alberto Cubillas
      (113, 'Terrones Barra, Ana María ', '260626453'), -- Ana Terrones
      (122, ' Maltseva, Anastasia', '260764881'), -- Anastasiya Maltseva
      (35, 'García Pérez, Andrés ', '260695681'), -- Andrés García
      (36, ' Honrado Peláez, Angelines', '260803356'), -- Angelines Honrado
      (37, 'Pardal Sousa, Antonio Alberto ', '260297382'), -- Antonio Pardal
      (38, '(Truchado) Arroyo Rando, Auri ', '260513811'), -- Auri Truchado
      (39, '(Iglesias) del Valle Pinto, Aurora ', '260918451'), -- Aurora Del Valle
      (40, 'Casais Riobó, Avelino ', '260677692'), -- Avelino Casáis
      (41, 'Fernández Suárez, Benilde ', '260572587'), -- Benilde Fernández
      (42, '(García) Rodríguez Colorado, Carolina ', '260566259'), -- Carolina Rodríguez
      (43, '(Pena) Casais Riobó, Clara ', '260468438'), -- Clara De Pena
      (45, '(Menéndez) Menéndez Muñoz, Covadonga ', '260348018'), -- Covadonga Menéndez
      (46, 'García Calderón, Cristina ', '260187440'), -- Cristina García
      (47, '(Kramer) Rus, Dana Edidia', '260484531'), -- Dana Rus
      (49, '(Estévez) Camacho Rojas, Danay ', '260173572'), -- Danay Estévez
      (50, 'Estévez Camacho, Daniel ', null), -- Daniel Estévez
      (51, 'Estévez Camacho, Daniela ', '260477225'), -- Daniela Estévez
      (52, 'Cubillas Gutiérrez, David ', null), -- David Cubillas
      (53, 'Álvarez Mouriño, David Walter ', '260348813'), -- David Walter
      (116, ' Antonio Arias, Débora', null), -- Debora Antonio
      (54, 'Pardal Brochas, Diego Antonio ', '260326954'), -- Diego Pardal
      (55, '(Casais) Gallego Fuentes, Elena ', '260646545'), -- Elena De Casáis
      (57, 'Alfonso Martínez,  Esmeralda ', '260610002'), -- Esmeralda Alfonso
      (58, 'Terrones Barra, Esmeralda ', '260960946'), -- Esmeralda Terrones
      (59, 'Fernández Fernández, Ezequiel ', '260909918'), -- Ezequiel Fernández
      (60, '(Costa) Farrapilla, Fernanda ', null), -- Fernanda De Costa
      (61, 'Iglesias Gutiérrez, Fco. Javier ', '260802607'), -- Francisco Iglésias
      (62, 'López Meza, Geni ', '260685671'), -- Geni López
      (63, 'Granados Targa, Gloria ', '260450187'), -- Gloria Granados
      (64, 'Vegas Marín, Hazael ', '260251056'), -- Hazael Vegas
      (72, 'Fernández Iglesias,  Hugo ', null), -- Hugo Fernández
      (65, 'Estévez Sanchez, Hector ', '260221695'), -- Héctor Estévez
      (123, 'Maltseva, Inesa ', null), -- Inessa Maltseva
      (66, 'Gutiérrez García, Irene ', '260144622'), -- Irene Gutiérrez
      (67, 'Menéndez Mori, Jair ', '260933183'), -- Jair Menéndez
      (68, '(Vegas) Suárez Povedano, Jair ', '260174514'), -- Jair Suárez
      (69, '(Arévalo) Casais Hernández, Janny Bell', '260243124'), -- Jannybel Casáis
      (70, 'Trapiello Fonseca, Jared ', '260433459'), -- Jared Trapiello
      (71, 'Cubillas Gutiérrez, Javier ', '260454587'), -- Javier Cubillas
      (73, 'Barreiro García, Jesús ', '260889197'), -- Jesús Barreiro
      (74, 'Barrufet Granados, Joan ', '260934724'), -- Joan Barrufet
      (75, 'García Ramos, Joaquín ', '260815509'), -- Joaquín García
      (76, 'Menéndez Menéndez, Jorge ', '260219242'), -- Jorge Menéndez
      (79, '(Casais) Hernández Hernández, Josefina ', '260404051'), -- Josefina De Casáis
      (77, 'Rodríguez Mateos, José Fco. ', '260821570'), -- José Francisco Rodríguez
      (78, 'Casais Hernández, José Luis ', '260337314'), -- José Luis Casáis
      (181, 'Sosa, José ', '674005946'), -- José Sosa
      (80, 'Guerras Otero, Juanjo ', '260745870'), -- Juanjo Guerras
      (81, '(Martínez) Trapiello Fonseca, Keren', null), -- Keren Trapiello
      (124, 'Maltseva, Kira ', '260800485'), -- Kira Maltseva
      (82, '(Trapiello) Fonseca Reguero, Lali ', '260987844'), -- Lali Fonseca
      (83, '(Antonio) del Valle Pinto,  Lidia', null), -- Lidia Del Valle
      (84, 'Alonso Grande, Loli ', '171770032'), -- Loli Marín
      (85, 'Fernández Iglesias, Lucas ', '260691127'), -- Lucas Fernández
      (86, '(Suárez) Povedano del Valle, Luchy ', '260217694'), -- Luchy De Suárez
      (87, 'Toledano Requena, Luisa ', '260352707'), -- Luisa Toledano
      (88, '(Alfonso) Martínez Pérez, Mabel', '260544696'), -- Mabel Martínez
      (91, 'Truchado Alonso, Manuel  Ángel ', '260723383'), -- Manuel Truchado
      (89, 'Casais Hernández, Manuel Angel ', null), -- Manuel Ángel Casáis
      (114, '(Blanco) Rodríguez Álvarez, Margarita ', '260311924'), -- Margarita De Blanco
      (93, '(García) Pérez Carbajo, Mª Carmen ', '260448167'), -- Mari De García
      (94, '(Rodríguez) de la Calle Honrado, Mª Luz ', '260846463'), -- Mari Luz De La Calle
      (95, 'González García, Mª Paz ', '260881103'), -- Mari Paz
      (119, '(Pardal) Brochas, María  del Cielo ', '260453589'), -- Maria de Pardal
      (96, '(Guerras) Fernández, Marigel ', '260402711'), -- Marigel Fernández
      (97, '(Pardal) Quintero Rodríguez, Marta', '260806015'), -- Marta Quintero
      (182, ' Sosa, Maureth', '487304494'), -- Maureth Sosa
      (98, '(Barrufet) Morón Soto, Mónica ', null), -- Mónica Morón
      (99, ' (Álvarez) Trapiello Fonseca, Naara', '260667938'), -- Naara Trapiello
      (100, ' Fandeeva, Natasha Viktorovna', '260372583'), -- Natasha Fandeeva
      (101, 'Trapiello Fonseca, Noemí ', null), -- Noemí Trapiello
      (102, 'Martínez Mirón, Omar ', '260128610'), -- Omar Martínez
      (103, '(Barreiro) Ortega Gómez,  Paquita ', '260180518'), -- Paquita Ortega
      (115, 'Blanco Lorenzo, Pedro ', '260718969'), -- Pedro Blanco
      (105, 'Suárez Román, Pedro ', '260946165'), -- Pedro Suárez
      (106, 'Arévalo Otero, Samuel', '260335303'), -- Samuel Arévalo
      (117, 'García Fernández, Samuel ', null), -- Samuel García
      (118, 'Trapiello Fernández, Secundino ', '260169407'), -- Secundino Trapiello
      (107, 'Suárez Povedano, Sergio ', '260318940'), -- Sergio Suárez
      (108, '(Fernández) Iglesias del valle, Sheila', '260662077'), -- Sheila Iglésias
      (109, '(Casais) Cubillas Gutiérrez, Susana ', '260788269'), -- Susana Cubillas
      (110, 'Voitova, Tamara ', '260454129'), -- Tamara Voitova
      (111, 'Dgelomanova, Valentina ', null), -- Valentina Dzhelomanova
      (112, '(Cubillas) Escobar González, Vanesa ', '260520900') -- Vanesa De Cubillas
    ) as v(id, external_name, external_id)
   where p.congregation_id = v_congregation_id
     and p.id = v.id;

end;
$$;
