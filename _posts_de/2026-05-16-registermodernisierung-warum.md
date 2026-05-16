---
layout: post
title: "Registermodernisierung: Warum eigentlich?"
subtitle: "Serie zur Registermodernisierung – Teil 1"
author: Tim Zöller
date: 2026-05-15 21:00:00 +0200
categories: registermodernisierung
---

Ich beschäftige mich jetzt schon seit einiger Zeit beruflich (in meiner Rolle als IT-Dienstleister) mit der
Registermodernisierung. In Gesprächen mit anderen Entwickler:innen fiel mir auf, dass das Thema auf viel Interesse
stößt, das Thema "Digitalisierung in der Verwaltung" aber auch auf viel Skepsis, Sarkasmus und Polemik. Dieser Artikel
soll eine Blogserie zu diesem Thema anstoßen, in der ich versuche fachlich neutral über das Thema zu schreiben, aber mir
trotzdem die ein oder andere persönliche Wertung erlaube. Dabei beziehe ich mich auf öffentlich zugängliche
Dokumentation zu Datenformaten und Prozessen. Mein Ziel ist, darüber zu informieren was jetzt und in ein paar Jahren
passiert, um die Digitalisierung in der Verwaltung voranzutreiben – ohne Polemik und Faxwitze.

Dafür habe ich in meinem Blog extra einen deutschsprachigen Bereich eingerichtet, da sich viele verwendete Begriffe und
Konzepte schlecht übersetzen lassen, und die Zielgruppe darüber hinaus eh deutschsprachig ist. Dabei werde ich manche
rechtliche Konstrukte vereinfacht darstellen, da es in dieser Blogserie hauptsächlich um den technischen und
architekturellen Teil der Registermodernisierung gehen soll.

## Das Ziel: Once-Only

Unter Once-Only versteht man das Konzept, dass Bürger:innen in Behörden ihre Daten lediglich einmal bekannt machen
müssen, die Verwaltungen tauschen sie danach untereinander aus. Sie müssen also nicht ihre Geburtsurkunde beglaubigt
kopieren lassen, um sie für Verwaltungsprozesse wieder einzureichen. Sie müssen keinen Nachweis über den Empfang der
Grundsicherung beantragen, um sich bei anderen Verwaltungen von gewissen Kosten befreien zu lassen. Sie müssen nach einem
Umzug nicht bei jeder einzelnen Behörde mit der sie zu tun haben ihre neue Adresse bekannt machen. Solche Daten sollen
zukünftig nur beim jeweils zuständigen Register angegeben werden müssen. Andere Verwaltungsverfahren, welche diese
Informationen benötigen, fragen sie selbstständig an (nach Einverständnis der Bürger:innen und für sie
transparent – ein Thema für einen späteren Artikel in dieser Serie).

## Hürden für die Digitalisierung

Das Erreichen von Once-Only ist leider nicht mit der Einführung einer neuen Software möglich. Der größere Aufwand
liegt darin, Vorbedingungen für solch eine Software und deren Anbindung überhaupt zu schaffen. Deutschland
hat nämlich [mehr als 375 Register](https://registerlandkarte.de/hauptfenster/registers?sort=name,DESC&size=10&page=0),
die Daten zu Bürger:innen, Unternehmen und Co enthalten. Diese Register haben zwei große Probleme: Sie haben
unterschiedliche Formate und Strukturen und sie haben kein einheitliches Personenkennzeichen. Die Leser:innen, die in
der Enterprise-IT in großen Unternehmen arbeiten, werden die folgenden drei Probleme im kleinen Maßstab kennen

### 1. Daten in Silos mit unterschiedlicher Struktur

Ein häufiges Problem in allen Unternehmen: Daten sind in vielen Silos eingeschlossen, und können durch ihre historisch
gewachsene Beschaffenheit nicht automatisiert verknüpft werden. Auf Registerebene ist dieses Problem ungleich schlimmer:
Die meisten Daten, die verknüpft werden müssten, um eine Behördendigitalisierung erst zu ermöglichen und Once-Only zu
erreichen, sind nicht automatisiert abrufbar. Selbst wenn Name, Vorname, Geburtsdatum und Adresse überall gleich und
vorbildlich gepflegt wären und als eindeutiges Abrufkriterium geeignet wären, hätten die ausgetauschten Datensätze
unterschiedliche Formate. Ein Nachname könnte beispielsweise in Register A 200 Zeichen lang sein, bei Register B 120
Zeichen und bei Register C unbegrenzt. Dies würde eigene Transformationsregeln für jedes einzelne Register erfordern. Um
beim Beispiel zu bleiben: Die Register des Bundes, der Länder, der Kommunen haben jahrzehntelang ihre
Enterprise-Architektur vernachlässigt. Das ist nicht verwunderlich und ich möchte das hier auch nicht verurteilen: Der
Bund, Länder und Kommunen haben mit den ihnen verfügbaren Mitteln Probleme durch Software gelöst. Ein übergreifendes
Datenformat und der Austausch waren dabei jahrelang nicht im Fokus.

### 2. Fehlende Identifikationsmerkmale

In Deutschland gibt es keine Nummer um Bürger:innen eindeutig zu identifizieren. Dieses Konzept gibt es beispielsweise
in Skandinavien häufig. Schweden hat die *personnummer*, Norwegen die *fødselsnummer*, Dänemark die *CPR-nummer*,
Finnland die *henkilötunnus*, Island die *kennitala*... Je nach Land ist die Verwendung hier unterschiedlich, generell
lässt sich aber sagen, dass Bürger:innen sich mit dieser Nummer bei Behörden und staatlichen Institutionen
identifizieren können. In den USA geschieht dies über die *Social Security Number*, auch wenn diese gar nicht dafür
gedacht war – dass Bürger:innen sich über diese identifizieren, hat sich nach und nach eingeschlichen. Eine ähnliche
Kennziffer in Deutschland einzuführen sollte also eigentlich kein Problem sein – oder?

Leider doch. In Deutschland ist der Datenschutz historisch wichtig, und das ist etwas Gutes. Zementiert wird das vom
sogenannten "Volkszählungsurteil" des Bundesverfassungsgerichts von 1983. Die Klage beschäftigte sich (von mir laienhaft
zusammengefasst) mit dem Versuch, einen Zensus durch Daten aus Registern zu unterstützen, anstatt alle Daten erneut
"von Hand" zu erheben. Konkret stellte das Gericht fest, dass aus der Möglichkeit der modernen Datenverarbeitung ein
neues Grundrecht folgen müsse: das Recht auf informationelle Selbstbestimmung. Es gewährleistet die Befugnis des
Einzelnen, grundsätzlich selbst über die Preisgabe und Verwendung der eigenen Daten zu bestimmen. Daraus leitete das
Gericht eine zentrale Schranke ab: Eine unbeschränkte Verknüpfung von Daten verschiedener Verwaltungsregister — gerade
über ein einheitliches Personenkennzeichen — würde es ermöglichen, umfassende Persönlichkeitsprofile zu erstellen, und
ist deshalb verfassungsrechtlich unzulässig (BVerfGE 65, 1 [47 f.]).

Ein Personenkennzeichen muss also in Deutschland auf eine Art und Weise eingeführt werden, welche die Bildung von
übergreifenden und umfassenden Bürger:innenprofilen verhindert. Ein schwieriges Unterfangen. Einer der nächsten Artikel
wird die derzeitige Lösung für das Problem betrachten.

### 3. Fehlende Infrastruktur zum Austausch

Das oben beschriebene Problem würde durch die Anbindung der Register untereinander noch schwerwiegender: Dies wird an
einem reduzierten Beispiel etwas greifbarer: Gäbe es nur 20 Register und nicht über 375, und müssten diese alle
bidirektional Daten miteinander austauschen, würden sich alle gegenseitig anbinden. Jedes Register würde also 19 andere
anbinden müssen, das wären 380 Verbindungen. 380-mal Mapping Logik, 380-mal eine abgesicherte Netzwerkverbindung
zwischen den Registern, potenziell mit unterschiedlichen Technologien und Protokollen. Dass hier eine gemeinsame Planung
und ein konzentrierter Aufwand nötig ist, liegt auf der Hand. Hier muss eine Kommunikationsinfrastruktur geschaffen
werden, welche einen gemeinsamen Rahmen schafft, ohne zu einem Single Point of Failure oder Datenbottleneck zu werden.

## Ausblick

Dieser Artikel stellt den Auftakt zu einer Serie dar, die aufzeigen soll wie die beschriebenen Probleme gelöst werden
können, sodass in den deutschen Verwaltungen das Ziel von Once-Only erreicht werden kann. Die nächsten Artikel werden die
Einführung (und Kontroversen) um ein einheitliches Identifikationsmerkmal für Bürger:innen behandeln, welche Gesetze
und Konzepte dieser zugrundeliegen und welche technischen Auswirkungen daraus resultieren: Das IDNrG für die Einführung
von Personenkennzeichen, XÖV Standards für die einheitliche Formatierung beim Austausch von Registerdaten und NOOTS als
Prozess und technische Infrastruktur für den Austausch von Nachweisen zwischen Registern.