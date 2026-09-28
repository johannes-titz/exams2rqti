Betreff: exams → rqti: Inline-CSS, Stylesheets und QTI-Paketierung

Hallo Achim,

beim Testen der Choice-Beispiele sind noch ein paar Formatierungsdetails
aufgetaucht. Bei `flags.Rmd` wird direkt ein HTML-Span mit
`style="font-size: 200%; vertical-align: middle"` erzeugt. Bei `fruit2.Rmd`
steht die Bildbreite als Markdown-Attribut `{width="0.85cm"}` im Beispiel;
Pandoc macht daraus `style="width:0.85cm"` am Bild. Das funktioniert als HTML,
aber diese Inline-Style-Attribute sind im Standard-QTI-2.1-Schema nicht erlaubt.

Die Formatierung lässt sich erhalten, indem die Elemente CSS-Klassen bekommen
und die Regeln in einer separaten CSS-Datei stehen. Für die beiden Beispiele
könnte die Quelldarstellung etwa so aussehen:

```html
<span class="exams-flag">🇦🇹</span>
```

```markdown
![Banane](banana.png){.exams-fruit}
```

Die zugehörige Datei `exercises.css` enthält:

```css
.exams-flag {
  font-size: 200%;
  vertical-align: middle;
}
.exams-fruit {
  width: 0.85cm;
}
```

Bei anderen Ausgabeformaten müsste die CSS-Datei ebenfalls eingebunden werden.
Alternativ kann der QTI-Exporter die bestehenden Inline-Styles erst nach der
HTML-Erzeugung in Klassen umwandeln. Dann bleiben die ursprünglichen
exams-Vorlagen unverändert. Genau diese zweite Variante habe ich für die beiden
bekannten Styles in einer kleinen Demo geprüft. Eine allgemeine automatische
CSS-Auslagerung ist damit noch nicht implementiert.

Bereits in rqti-Version 1.3.0 ist die Paketierung einer CSS-Datei
bereits auf AssessmentTest-Ebene implementiert:

```r
assessment <- rqti::assessmentTest(
  section = list(rqti::assessmentSection(items, identifier = "choices")),
  identifier = "exam",
  stylesheet_path = "exercises.css",
  rebuild_variables = NA
)
rqti::createQtiTest(assessment, dir = "qti-output")
```

rqti kopiert die Datei nach `styles/exercises.css` in das ZIP, schreibt einen
`stylesheet`-Verweis in die Test-XML und trägt die Datei im Test-Resource-Eintrag
der `imsmanifest.xml` ein. `rebuild_variables = NA` lässt zusätzlich das
nichtstandardisierte `rebuildVariables`-Attribut weg.

Die veröffentlichte rqti-Version 1.3.0 unterstützt diese Angaben noch nicht im
YAML-Kopf einer einzelnen Rmd-Aufgabe. Im lokalen rqti-Checkout wurde diese
Unterstützung jetzt ergänzt, als `f2b1621d` committet und lokal als
Version `1.3.1.9000` installiert (noch nicht veröffentlicht):

```yaml
identifier: flags
type: sc
stylesheet_path: exercises.css
```

Alternativ kann CSS direkt als Text im Aufgaben-YAML stehen:

```yaml
identifier: flags
type: sc
css: |
  .exams-flag { font-size: 200%; vertical-align: middle; }
```

Dateipfade werden relativ zur Rmd-Datei aufgelöst. Auch mehrere Dateien als
YAML-Liste sind möglich. Wenn beide Felder vorkommen, folgen die eingebetteten
Regeln auf die Dateien. Die Stylesheets werden in der Item-XML referenziert
und beim ZIP-Export einschließlich Manifest verpackt, auch bei einzelnen
Items, verschachtelten Sections und Aufgabenvarianten. Beim reinen XML-Export
muss das erzeugte Verzeichnis `styles/items/` zusammen mit der XML erhalten
bleiben. Die Umwandlung vorhandener Inline-Styles in Klassen bleibt eine
separate Aufgabe; CSS-Abhängigkeiten über `url()` oder `@import` werden nicht
automatisch eingesammelt.

Ein anschließender Pakettest hat auch benannte Item-Listen abgedeckt. Der
ergänzende Commit `ecb24296` stellt sicher, dass deren Stylesheets im jeweiligen
Manifest-Resource-Eintrag stehen; dieser Stand ist ebenfalls lokal installiert.

Für die Kompatibilität mit Version 1.3.0 verwendet das bisherige Demo eine separate
Konfigurationsdatei.
Ein kleiner R-Wrapper liest beispielsweise:

```yaml
identifier: exam
title: Choice examples
stylesheet_path: exercises.css
```

mit `yaml::read_yaml()`, löst den CSS-Pfad relativ zur Konfigurationsdatei auf
und reicht ihn an `assessmentTest()` weiter. CSS direkt als YAML-Text ist mit
demselben Prinzip möglich:

```yaml
identifier: exam
title: Choice examples
css: |
  .exams-flag { font-size: 200%; vertical-align: middle; }
  .exams-fruit { width: 0.85cm; }
```

Hier schreibt der Wrapper den Text zunächst in eine CSS-Datei und übergibt
deren Pfad an rqti. Das ist eine explizite Ergänzung im Demo-Wrapper und
unabhängig von der neuen nativen YAML-Schnittstelle im rqti-Checkout.

Beide Varianten sind in `notes/css-demo/` nachvollziehbar. Geprüft sind die
CSS-Datei im tatsächlichen ZIP, ihr unveränderter Inhalt, der XML-Verweis und
der Manifest-Eintrag. Nach der Umstellung auf Klassen validieren die beiden
Items (`flags`, `fruit2`) und die Test-XML gegen das Standard-QTI-Schema.

Im bisherigen Demo sitzt die Referenz am Test. Die neue native YAML-Funktion
referenziert CSS dagegen aus den einzelnen Item-XML-Dateien. Der visuelle
Importtest im jeweiligen LMS steht noch aus; Schema-Validität allein
garantiert nicht, dass ein LMS das CSS wie beabsichtigt darstellt.

Das neue Beispiel `inst/examples/css-choice-variants.R` erstellt zusätzlich
Item-CSS-Versionen von `flags`, `fruit2`, `logic` und `automaton`, jeweils mit
Seeds 0 und 17. Alle acht Varianten bestehen `verify_qti()`. Die Regressionstests
machen ausschließlich die CSS-Auslagerung rückgängig und vergleichen dann den
kompletten XML-Baum mit dem Original: Text, Bilddaten, Tabellen, Mathematik,
Feedback und Bewertung bleiben erhalten. Die Originale mit Inline-CSS werden
zum Vergleich ebenfalls exportiert und bleiben erwartungsgemäß schema-ungültig.

Die vorherigen ImageMagick-Fehler waren übrigens ein lokales Bibliotheksproblem.
Nach dem Neubau des R-Pakets `magick` laufen die TikZ-Beispiele `logic.Rmd` und
`automaton.Rmd` durch die Bildgenerierung. Bei der QTI-Prüfung taucht anschließend
ebenfalls Inline-CSS für Bildbreiten auf; dafür gilt derselbe Ansatz.

Für die Zusammenarbeit würde ich die Zuständigkeit so lassen: exams rendert
die Aufgaben, der Adapter übersetzt die Choice-Objekte und erkennt die
QTI-relevanten Formatierungsfälle, rqti übernimmt die QTI-Serialisierung und
Paketierung. Eine native CSS-YAML-Schnittstelle wäre eine überschaubare weitere
Ergänzung, sollte aber Item- und Test-Ebene ausdrücklich unterscheiden.

Viele Grüße
Johannes

Technische Quellen:

- [QTI 2.1: Formatting Items with Stylesheets](https://www.imsglobal.org/question/qtiv2p1/imsqti_infov2p1.html)
- [rqti Changelog: stylesheet_path an AssessmentTest](https://shevandrin.github.io/rqti/news/index.html)
- Zusätzlich geprüft: installierter rqti-1.3.0-Code (`assessmentTest`,
  `create_assessment_test`, `create_qti_test`, `create_stylesheet_file_tags`,
  `create_question_object`, `rmd2zip`) und die tatsächlich erzeugten ZIP-Dateien.
