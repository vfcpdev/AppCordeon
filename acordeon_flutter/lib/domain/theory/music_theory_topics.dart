import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Modelo de un tema o módulo de teoría musical aplicada al acordeón.
class MusicTheoryTopic {
  final String id;
  final String title;
  final String subtitle;
  final String level; // 'Básico', 'Intermedio', 'Avanzado'
  final Color levelColor;
  final IconData icon;
  final List<TheorySectionItem> sections;

  const MusicTheoryTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.levelColor,
    required this.icon,
    required this.sections,
  });
}

class TheorySectionItem {
  final String heading;
  final String description;
  final List<String>? bulletPoints;
  final String? musicalDiagram;
  final String? accordionTip;
  final Map<String, String>? tableData;

  const TheorySectionItem({
    required this.heading,
    required this.description,
    this.bulletPoints,
    this.musicalDiagram,
    this.accordionTip,
    this.tableData,
  });
}

/// Repositorio de los 7 módulos educativos de teoría musical aplicada al acordeón diatónico.
class MusicTheoryCatalog {
  static const List<MusicTheoryTopic> topics = [
    // ─── 1. EL PENTAGRAMA Y LAS CLAVES ──────────────────────────────────────
    MusicTheoryTopic(
      id: 'pentagrama',
      title: '1. El Pentagrama y las Claves',
      subtitle: 'Lectura musical aplicada a los 31 botones y 12 bajos',
      level: 'Básico',
      levelColor: Color(0xFF16A34A), // Verde
      icon: FontAwesomeIcons.linesLeaning,
      sections: [
        TheorySectionItem(
          heading: '¿Qué es el Pentagrama?',
          description:
              'El pentagrama es la base gráfica donde se escribe la música. Consta de 5 líneas paralelas horizontales y 4 espacios intermedios, contados siempre de abajo hacia arriba.',
          bulletPoints: [
            'Líneas: 1ª (Mi), 2ª (Sol), 3ª (Si), 4ª (Re), 5ª (Fa) en Clave de Sol.',
            'Espacios: 1º (Fa), 2º (La), 3º (Do), 4º (Mi) en Clave de Sol.',
            'Líneas adicionales: Se emplean por encima o por debajo para registrar notas agudas o graves fuera del rango estándar.',
          ],
          musicalDiagram: 'E4 (L1) ── G4 (L2) ── B4 (L3) ── D5 (L4) ── F5 (L5)',
          accordionTip:
              'En el acordeón diatónico, la mano derecha (diapasón melódico) lee principalmente en Clave de Sol, mientras que la mano izquierda (panel de bajos) lee en Clave de Fa.',
        ),
        TheorySectionItem(
          heading: 'Correspondencia Física con el Diapasón Melódico',
          description:
              'Los 31 botones de la mano derecha abarcan casi 3 octavas completas (desde La3 hasta Do7 en afinación Cinco Letras). Cada botón representa una posición precisa en el pentagrama.',
          bulletPoints: [
            'Hilera 1 (Afuera): Diseñada para la tonalidad principal (ej. Si♭). Contiene 10 botones.',
            'Hilera 2 (Medio): Subdominante directa (ej. Mi♭). Contiene 11 botones con el rango más equilibrado.',
            'Hilera 3 (Adentro): Tonalidad complementaria (ej. La♭). Contiene 10 botones con notas agudas extendidas.',
          ],
          accordionTip:
              'Memorizar la nota central Do4 (Línea adicional inferior en Clave de Sol) es clave para ubicarse rápidamente en los botones 2 de la hilera 1 abriendo o botón 5 de la hilera 2 abriendo.',
        ),
      ],
    ),

    // ─── 2. SIMBOLOGÍA Y FUELLE ─────────────────────────────────────────────
    MusicTheoryTopic(
      id: 'simbologia',
      title: '2. Simbología y Fuelle',
      subtitle: 'Mecánica bisonora, abrir vs cerrar y sistemas de cifrado',
      level: 'Básico',
      levelColor: Color(0xFF16A34A), // Verde
      icon: FontAwesomeIcons.arrowsLeftRight,
      sections: [
        TheorySectionItem(
          heading: 'El Acordeón Diatónico es Bisonoro',
          description:
              'A diferencia del piano o acordeón cromático, en el acordeón diatónico vallenato cada botón produce dos notas diferentes según el sentido del flujo de aire en el fuelle.',
          bulletPoints: [
            'CERRAR (Push / Empujando): Se representa con una flecha roja hacia la derecha (→) o el símbolo (+). Produce principalmente notas de la tríada de tónica.',
            'ABRIR (Pull / Halando): Se representa con una flecha azul hacia la izquierda (←) o el símbolo (-). Produce notas de paso, subdominantes y dominantes.',
          ],
          musicalDiagram: 'Botón 4 (Hilera 1): Cerrar = Fa4 (Push) │ Abrir = Sol4 (Pull)',
          accordionTip:
              'La articulación musical vallenata depende del "braceo": coordinar el cambio de fuelle con el acento rítmico de la caja y la guacharaca.',
        ),
        TheorySectionItem(
          heading: 'Cifrado Armónico: Latino vs Americano',
          description:
              'El cifrado es la abreviatura universal para nombrar notas y acordes en partituras y guías armónicas.',
          tableData: {
            'Do / Do Mayor': 'C / C Maj',
            'Re / Re menor': 'D / Dm',
            'Mi / Mi 7ma': 'E / E7',
            'Fa / Fa Mayor': 'F / F Maj',
            'Sol / Sol sus4': 'G / Gsus4',
            'La / La menor 7': 'A / Am7',
            'Si♭ / Si bemol': 'Bb / B flat',
          },
          accordionTip:
              'En este simulador puedes alternar entre Notación Latina y Alemana/Americana con un solo clic en la cabecera superior.',
        ),
      ],
    ),

    // ─── 3. CÍRCULO DE QUINTAS Y LAS 3 HILERAS ──────────────────────────────
    MusicTheoryTopic(
      id: 'circulo_quintas',
      title: '3. Círculo de Quintas y Hileras',
      subtitle: 'La arquitectura armónica del acordeón diatónico de 3 hileras',
      level: 'Intermedio',
      levelColor: Color(0xFF0284C7), // Azul
      icon: FontAwesomeIcons.circleNodes,
      sections: [
        TheorySectionItem(
          heading: 'El Círculo de Quintas: La Brújula Armónica',
          description:
              'El Círculo de Quintas organiza las 12 tonalidades por intervalos de quinta justa ascendente (en sentido horario) o cuarta justa (en sentido antihorario).',
          musicalDiagram: '... ← D♭ ── A♭ ── E♭ ── B♭ ── F ── C ── G ── D ...',
          bulletPoints: [
            'Tonalidades vecinas comparten casi todas sus notas (difieren solo en una alteración).',
            'El movimiento en sentido horario añade sostenidos (♯); en sentido antihorario añade bemoles (♭).',
          ],
          accordionTip:
              '¡Las 3 hileras del acordeón están conectadas por cuartas y quintas directas! En un Cinco Letras (B♭ - E♭ - A♭): de afuera hacia adentro subes por cuartas (B♭ → E♭ → A♭); de adentro hacia afuera bajas por quintas (A♭ → E♭ → B♭).',
        ),
        TheorySectionItem(
          heading: 'Relación Tónica - Subdominante - Dominante (I - IV - V)',
          description:
              'Cada hilera está flanqueada armónicamente por sus grados tonales fundamentales.',
          tableData: {
            'Hilera 1 (Afuera: B♭)': 'Tónica (I) = B♭ │ Subdominante (IV) = E♭ │ Dominante (V) = F',
            'Hilera 2 (Medio: E♭)': 'Tónica (I) = E♭ │ Subdominante (IV) = A♭ │ Dominante (V) = B♭',
            'Hilera 3 (Adentro: A♭)': 'Tónica (I) = A♭ │ Subdominante (IV) = D♭ │ Dominante (V) = E♭',
          },
          accordionTip:
              'Esta disposición física permite tocar el 80% de los paseos y merengues moviéndose lateralmente entre botones contiguos de hileras adyacentes.',
        ),
      ],
    ),

    // ─── 4. TIPOS DE ESCALAS Y DIGITACIONES ─────────────────────────────────
    MusicTheoryTopic(
      id: 'escalas',
      title: '4. Escalas y Digitaciones',
      subtitle: 'Escalas mayores, menores, pentatónicas, terceras y sextas',
      level: 'Intermedio',
      levelColor: Color(0xFF0284C7), // Azul
      icon: FontAwesomeIcons.stairs,
      sections: [
        TheorySectionItem(
          heading: 'Escala Mayor Natural',
          description:
              'La escala base de la música occidental. Sigue la fórmula interválica: Tono - Tono - Semitono - Tono - Tono - Tono - Semitono (T-T-s-T-T-T-s).',
          musicalDiagram: '1 (Tónica) ─ 2 (Mayor) ─ 3 (Mayor) ─ 4 (Justa) ─ 5 (Justa) ─ 6 (Mayor) ─ 7 (Mayor)',
          bulletPoints: [
            'En el acordeón diatónico, la escala mayor se ejecuta combinando el fuelle: notas 1, 3, 5 cierran; notas 2, 4, 6, 7 abren.',
            'Digitación lineal: Se puede tocar íntegramente en una sola hilera o cruzando botones para mayor velocidad.',
          ],
          accordionTip:
              'Cuando cierras el fuelle tocas la tríada de tónica; cuando abres tocas el resto de las notas de la escala.',
        ),
        TheorySectionItem(
          heading: 'Escalas Menores: Natural, Armónica y Melódica',
          description:
              'Tienen su tercera menor a 3 semitonos de la tónica, confiriéndoles un carácter nostálgico característico del Son y de cantos vallenatos sentimentales.',
          bulletPoints: [
            'Menor Natural: 1 - 2 - ♭3 - 4 - 5 - ♭6 - ♭7 (Modo Eólico, relativo de la hilera).',
            'Menor Armónica: 1 - 2 - ♭3 - 4 - 5 - ♭6 - 7 (Posee sensible mayor a medio tono de la tónica, ideal para cadencias V7 - i).',
            'Menor Melódica: Sube con 6ta y 7ma mayores, desciende como menor natural.',
          ],
          accordionTip:
              'En el acordeón vallenato, para hacer la sensible en menor armónica se toma prestado el botón de la hilera vecina.',
        ),
        TheorySectionItem(
          heading: 'Intervalos Dobles Tradicionales: Terceras, Sextas y Octavas',
          description:
              'La marca inconfundible del estilo vallenato clásico es la ejecución a dos voces simultáneas.',
          bulletPoints: [
            'Terceras: Se ejecutan pulsando dos botones contiguos o separados por un botón según la hilera.',
            'Sextas: Producen un sonido amplio y dulce. Se tocan cruzando entre dos hileras diferentes.',
            'Octavas: Dos notas idénticas a 12 semitonos de distancia. Dan fuerza y presencia en paseos y puyas.',
          ],
          accordionTip:
              'Usa la opción de "Octava" y "Extensión" en el Constructor Libre para visualizar de inmediato qué botones presionar.',
        ),
      ],
    ),

    // ─── 5. ACORDES, CUATRÍADAS E INVERSIONES ───────────────────────────────
    MusicTheoryTopic(
      id: 'acordes',
      title: '5. Acordes e Inversiones',
      subtitle: 'Estructuras armónicas, cuatríadas y acordes con barra (Slash Chords)',
      level: 'Intermedio - Avanzado',
      levelColor: Color(0xFF7C3AED), // Morado
      icon: FontAwesomeIcons.guitar,
      sections: [
        TheorySectionItem(
          heading: 'Tríadas Fundamentales',
          description:
              'Un acorde de tres notas formadas por superposición de terceras sobre una fundamental.',
          tableData: {
            'Tríada Mayor (1 - 3 - 5)': 'Tónica + 3ª Mayor (4 st) + 5ª Justa (7 st). Ej: Do - Mi - Sol',
            'Tríada Menor (1 - ♭3 - 5)': 'Tónica + 3ª Menor (3 st) + 5ª Justa (7 st). Ej: Do - Mi♭ - Sol',
            'Disminuida (1 - ♭3 - ♭5)': 'Tónica + 3ª Menor (3 st) + 5ª Disminuida (6 st). Ej: Do - Mi♭ - Sol♭',
            'Aumentada (1 - 3 - ♯5)': 'Tónica + 3ª Mayor (4 st) + 5ª Aumentada (8 st). Ej: Do - Mi - Sol♯',
            'Suspendido 4 (1 - 4 - 5)': 'Tónica + 4ª Justa (5 st) + 5ª Justa (7 st). Ej: Do - Fa - Sol',
          },
          accordionTip:
              'El detector inteligente reconoce automáticamente estas 5 fórmulas evaluando las notas que tienes presionadas en el diapasón.',
        ),
        TheorySectionItem(
          heading: 'Cuatríadas y Acordes de Séptima',
          description:
              'Acordes de 4 notas que añaden riqueza, tensión o calidez armónica a las melodías.',
          bulletPoints: [
            'Séptima Dominante (7): Tríada Mayor + 7ª Menor (10 st). Motor de resolución hacia la tónica.',
            'Séptima Mayor (maj7): Tríada Mayor + 7ª Mayor (11 st). Sonido elegante y jazzístico.',
            'Menor Séptima (m7): Tríada Menor + 7ª Menor (10 st). Base de los grados ii y vi.',
            'Disminuida 7ma (°7): Tríada Disminuida + 7ª Disminuida (9 st). Acorde simétrico de paso.',
          ],
          accordionTip:
              'En el acordeón vallenato, la 7ma dominante se usa con frecuencia al abrir el fuelle para resolver al acorde de tónica al cerrar.',
        ),
        TheorySectionItem(
          heading: 'Inversiones y Acordes con Barra (Slash Chords /)',
          description:
              'Una inversión ocurre cuando la nota más grave del acorde (el bajo) no es la tónica fundamental.',
          bulletPoints: [
            'Estado Fundamental: El bajo es la tónica (ej. Do).',
            '1ª Inversión (ej. Do/Mi o C/E): El bajo está en la 3ª. Proporciona conducción melódica en el bajo.',
            '2ª Inversión (ej. Do/Sol o C/G): El bajo está en la 5ª. Muy usado en cadencias.',
            '3ª Inversión (ej. Do7/Si♭ o C7/B♭): El bajo está en la 7ª. Conduce con fuerza hacia el IV grado.',
          ],
          accordionTip:
              'El Constructor Libre cuenta con la matriz "Bajo (/)" que te permite elegir /3, /5 y /7, y el Detector de Acordes reconoce la inversión automáticamente.',
        ),
      ],
    ),

    // ─── 6. PROGRESIONES ARMÓNICAS Y CADENCIAS ──────────────────────────────
    MusicTheoryTopic(
      id: 'progresiones',
      title: '6. Progresiones y Cadencias',
      subtitle: 'Estructuras de Paseo, Merengue, Son, Puya y secuencias de acordes',
      level: 'Avanzado',
      levelColor: Color(0xFFEA580C), // Naranja
      icon: FontAwesomeIcons.diagramProject,
      sections: [
        TheorySectionItem(
          heading: 'Cadencias Armónicas Fundamentales',
          description:
              'Una cadencia es una sucesión de acordes que marca el final de una frase musical, similar a un punto o coma en el lenguaje hablado.',
          bulletPoints: [
            'Cadencia Auténtica (V → I o V7 → I): La resolución más contundente y definitiva.',
            'Cadencia Plagal (IV → I): Conocida como la cadencia "Amén", transmite reposo suave.',
            'Semicadencia (? → V): Deja la frase en suspenso, esperando continuar.',
            'Cadencia Rota o Decepsionada (V → vi): El oído espera la tónica pero resuelve al grado menor.',
          ],
          musicalDiagram: 'Frase A: I ── IV ── V (Suspensa) │ Frase B: I ── IV ── V7 ── I (Auténtica)',
        ),
        TheorySectionItem(
          heading: 'La Progresión Reina del Vallenato (I - IV - V - I)',
          description:
              'El 90% de la música de acordeón tradicional se sostiene en la alternancia simétrica entre Tónica, Subdominante y Dominante.',
          musicalDiagram: '│ I (Tónica: Cierra) │ IV (Subdominante: Abre) │ V7 (Dominante: Abre) │ I (Tónica: Cierra) │',
          accordionTip:
              'En la cuadrícula de compases puedes insertar fácilmente esta progresión en 4 compases y sincronizarla con el fuelle para practicarla.',
        ),
        TheorySectionItem(
          heading: 'Progresiones en Tonalidad Menor y Círculos Armónicos',
          description:
              'En composiciones menores, se combinan grados menores con dominantes mayores alterados.',
          tableData: {
            'Progresión Menor Clásica': 'i (Menor) → iv (Subdominante menor) → V7 (Dominante Mayor) → i',
            'Círculo de Grados (Pop/Paseo)': 'I → vi (Relativo menor) → ii (Menor) → V7',
            'Descenso Andaluz': 'i → ♭VII → ♭VI → V7 (Muy usado en introducciones dramáticas de Son)',
          },
        ),
      ],
    ),

    // ─── 7. TÉCNICA DE BAJOS Y HOMÓNIMOS ────────────────────────────────────
    MusicTheoryTopic(
      id: 'bajos',
      title: '7. Bajos, Acompañamiento y Homónimos',
      subtitle: 'La mano izquierda: técnica tump-tá, bajo alternante y bajos menores',
      level: 'Avanzado',
      levelColor: Color(0xFFEA580C), // Naranja
      icon: FontAwesomeIcons.drum,
      sections: [
        TheorySectionItem(
          heading: 'El Panel de 12 Bajos: Mano Izquierda',
          description:
              'Los 12 botones de bajos están ordenados en 2 columnas verticales de 6 botones cada una: Columnas de Bajos Fundamentales (notas simples en octavas graves) y Columnas de Acordes de acompañamiento (tríadas precompuestas).',
          bulletPoints: [
            'Patrón "Tump - Tá": En compás de 4/4 o 2/4, el bajo fundamental suena en el pulso fuerte (Tump) y el acorde en el pulso débil (tá).',
            'Bajo Alternante: En el primer tiempo tocas la tónica; en el tercer tiempo tocas la quinta superior o inferior.',
          ],
          accordionTip:
              'Al activar el botón Play o Arpegio en el simulador, verás cómo los botones de bajos se presionan sincronizados con el fuelle actual.',
        ),
        TheorySectionItem(
          heading: 'Bajos Homónimos (Fa Mayor vs Fa menor / Do Mayor vs Do menor)',
          description:
              'El acordeón de 12 bajos posee botones con la MISMA TÓNICA pero en distinta modalidad armónica.',
          tableData: {
            'Fa en Apertura (Pull)': 'Par 1 = Fa Mayor (Fa - La - Do) │ Par 4 = Fa menor (Fa - La♭ - Do)',
            'Do en Fuelle': 'Par 4 Cerrando = Do Mayor (Do - Mi - Sol) │ Par 2 Abriendo = Do menor (Do - Mi♭ - Sol)',
          },
          accordionTip:
              'Cuando toques una canción en tono menor (ej. Fa menor), asegúrate de usar el botón de acorde Par 4 abriendo. Nuestro motor armónico detecta y resalta automáticamente el bajo y acorde correcto según el modo.',
        ),
      ],
    ),
  ];
}
