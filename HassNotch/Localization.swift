import SwiftUI

/// The app's languages.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case ro, en, de, fr

    var id: Self { self }

    /// The language's name in that language, so anyone can recognize it.
    var nativeName: String {
        switch self {
        case .ro: "Română"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        }
    }

    var flag: String {
        switch self {
        case .ro: "🇷🇴"
        case .en: "🇬🇧"
        case .de: "🇩🇪"
        case .fr: "🇫🇷"
        }
    }

    /// The saved language or, on first launch, the system language (English if it isn't one of the four).
    static var initial: AppLanguage {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: saved) {
            return language
        }
        let system = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return AppLanguage(rawValue: system) ?? .en
    }
}

nonisolated enum Localization {
    /// The current language; changed by NotchSettings.language.
    nonisolated(unsafe) static var current: AppLanguage = .initial

    /// The key is the Romanian text; other languages look up their translation.
    static func text(_ key: String) -> String {
        guard current != .ro else { return key }
        return table[key]?[current] ?? key
    }

    static let table: [String: [AppLanguage: String]] = [
        "Informații afișate": [.en: "Displayed information", .de: "Angezeigte Informationen", .fr: "Informations affichées"],
        "Alege ce entități apar în insulă. Încap maximum %@: câte %@ pe rând, pe cel mult %@ rânduri. Indicatoarele se micșorează automat pe măsură ce adaugi. Selecțiile se salvează automat.": [.en: "Choose which entities appear in the island. Up to %@ fit: %@ per row, in at most %@ rows. Gauges shrink automatically as you add more. Selections are saved automatically.", .de: "Wähle, welche Entitäten in der Insel erscheinen. Es passen höchstens %@: %@ pro Zeile, in höchstens %@ Zeilen. Die Anzeigen werden beim Hinzufügen automatisch kleiner. Die Auswahl wird automatisch gespeichert.", .fr: "Choisissez les entités affichées dans l’îlot. Jusqu’à %@ au maximum : %@ par ligne, sur %@ lignes au plus. Les jauges rétrécissent automatiquement à mesure que vous en ajoutez. Les choix sont enregistrés automatiquement."],
        "Nicio entitate afișată. Apasă + ca să adaugi una.": [.en: "No entities shown. Press + to add one.", .de: "Keine Entitäten angezeigt. Drücke +, um eine hinzuzufügen.", .fr: "Aucune entité affichée. Appuyez sur + pour en ajouter une."],
        "Adaugă o entitate": [.en: "Add an entity", .de: "Entität hinzufügen", .fr: "Ajouter une entité"],
        "Scoate ultima entitate": [.en: "Remove the last entity", .de: "Letzte Entität entfernen", .fr: "Retirer la dernière entité"],
        "%@ din %@": [.en: "%@ of %@", .de: "%@ von %@", .fr: "%@ sur %@"],
        "Animație cifre": [.en: "Digit animation", .de: "Ziffernanimation", .fr: "Animation des chiffres"],
        "Rolă: cifrele se derulează în sus sau în jos prin valorile intermediare, ca la pompele de benzină vechi. Simplă: cifra se schimbă direct.": [.en: "Rolling: digits roll up or down through the intermediate values, like on old petrol pumps. Simple: the digit changes directly.", .de: "Walze: Die Ziffern rollen über die Zwischenwerte nach oben oder unten, wie bei alten Zapfsäulen. Einfach: Die Ziffer wechselt direkt.", .fr: "Rouleau : les chiffres défilent vers le haut ou le bas en passant par les valeurs intermédiaires, comme sur les anciennes pompes à essence. Simple : le chiffre change directement."],
        "Valorile se actualizează în timp real (sau la 30 de secunde, dacă conexiunea în timp real nu e disponibilă). Intervalele (min/max) se iau din cardurile Gauge ale dashboard-urilor Home Assistant, dacă nu le scrii tu.": [.en: "Values update in real time (or every 30 seconds if the real-time connection isn’t available). Ranges (min/max) are taken from the Gauge cards in your Home Assistant dashboards unless you enter them yourself.", .de: "Die Werte werden in Echtzeit aktualisiert (oder alle 30 Sekunden, wenn die Echtzeitverbindung nicht verfügbar ist). Die Bereiche (Min/Max) werden aus den Gauge-Karten deiner Home-Assistant-Dashboards übernommen, sofern du sie nicht selbst einträgst.", .fr: "Les valeurs sont mises à jour en temps réel (ou toutes les 30 secondes si la connexion en temps réel n’est pas disponible). Les plages (min/max) proviennent des cartes Gauge de vos tableaux de bord Home Assistant, sauf si vous les saisissez vous-même."],
        "Recitește intervalele din HA": [.en: "Reload ranges from HA", .de: "Bereiche aus HA neu laden", .fr: "Recharger les plages depuis HA"],
        "Actualizează acum": [.en: "Refresh now", .de: "Jetzt aktualisieren", .fr: "Actualiser maintenant"],
        "Afișează mereu (și pe insula închisă)": [.en: "Always show (also on the closed island)", .de: "Immer anzeigen (auch auf der geschlossenen Insel)", .fr: "Toujours afficher (aussi sur l’îlot fermé)"],
        "Poziție": [.en: "Position", .de: "Position", .fr: "Position"],
        "Nu mai e loc pe insula închisă pentru %@.": [.en: "No room left on the closed island for %@.", .de: "Kein Platz mehr auf der geschlossenen Insel für %@.", .fr: "Plus de place sur l’îlot fermé pour %@."],
        "Sunt deja %@ valori afișate mereu — maximul pentru %@.": [.en: "There are already %@ always-shown values — the maximum for %@.", .de: "Es werden bereits %@ Werte immer angezeigt – das Maximum für %@.", .fr: "Il y a déjà %@ valeurs toujours affichées — le maximum pour %@."],
        "Dynamic Island: 1 valoare la mijloc, 2 în stânga și dreapta, 3 pe toate locurile. Notch: maximum 2, stânga și dreapta.": [.en: "Dynamic Island: 1 value in the middle, 2 on the left and right, 3 in all spots. Notch: up to 2, left and right.", .de: "Dynamic Island: 1 Wert in der Mitte, 2 links und rechts, 3 auf allen Plätzen. Notch: höchstens 2, links und rechts.", .fr: "Dynamic Island : 1 valeur au centre, 2 à gauche et à droite, 3 sur tous les emplacements. Encoche : 2 au maximum, à gauche et à droite."],
        "Arată pe notch dacă se încarcă (⚡) sau se descarcă (↓)": [.en: "Show on the notch whether it is charging (⚡) or discharging (↓)", .de: "Auf dem Notch anzeigen, ob geladen (⚡) oder entladen (↓) wird", .fr: "Afficher sur l’encoche si la batterie se charge (⚡) ou se décharge (↓)"],
        "Sursă": [.en: "Source", .de: "Quelle", .fr: "Source"],
        "Se deduce din cum se schimbă valoarea: urcă = se încarcă, scade = se descarcă. Mai lent, pentru că procentul se schimbă rar.": [.en: "Inferred from how the value changes: rising = charging, falling = discharging. Slower, because the percentage changes rarely.", .de: "Wird aus der Änderung des Werts abgeleitet: steigt = lädt, fällt = entlädt. Langsamer, weil sich der Prozentwert selten ändert.", .fr: "Déduit de l’évolution de la valeur : hausse = en charge, baisse = en décharge. Plus lent, car le pourcentage change rarement."],
        "Alege senzorul…": [.en: "Choose the sensor…", .de: "Sensor auswählen…", .fr: "Choisir le capteur…"],
        "Inversează semnul (pentru invertoarele unde pozitiv = descărcare)": [.en: "Invert the sign (for inverters where positive = discharging)", .de: "Vorzeichen umkehren (für Wechselrichter, bei denen positiv = Entladen)", .fr: "Inverser le signe (pour les onduleurs où positif = décharge)"],
        "Acum: %@": [.en: "Now: %@", .de: "Jetzt: %@", .fr: "Maintenant : %@"],
        "Interval": [.en: "Range", .de: "Bereich", .fr: "Plage"],
        "preluat %@": [.en: "taken %@", .de: "übernommen %@", .fr: "repris %@"],
        "setat manual": [.en: "set manually", .de: "manuell festgelegt", .fr: "défini manuellement"],
        "HA nu are interval · completează min și max": [.en: "HA has no range · fill in min and max", .de: "HA hat keinen Bereich · Min und Max eintragen", .fr: "HA n’a pas de plage · renseignez min et max"],
        "max trebuie să fie mai mare decât min": [.en: "max must be greater than min", .de: "Max muss größer als Min sein", .fr: "max doit être supérieur à min"],
        "Ia din HA": [.en: "Take from HA", .de: "Aus HA übernehmen", .fr: "Reprendre de HA"],
        "Pune intervalul definit în Home Assistant": [.en: "Use the range defined in Home Assistant", .de: "Den in Home Assistant definierten Bereich verwenden", .fr: "Utiliser la plage définie dans Home Assistant"],
        "Alege o entitate…": [.en: "Choose an entity…", .de: "Entität auswählen…", .fr: "Choisir une entité…"],
        "Etichetă": [.en: "Label", .de: "Beschriftung", .fr: "Libellé"],
        "Etichetă (opțional)": [.en: "Label (optional)", .de: "Beschriftung (optional)", .fr: "Libellé (facultatif)"],
        "Afișare": [.en: "Display", .de: "Darstellung", .fr: "Affichage"],
        "Iconiță": [.en: "Icon", .de: "Symbol", .fr: "Icône"],
        "Scoate această entitate": [.en: "Remove this entity", .de: "Diese Entität entfernen", .fr: "Retirer cette entité"],
        "Exemplu": [.en: "Example", .de: "Beispiel", .fr: "Exemple"],
        "Stânga": [.en: "Left", .de: "Links", .fr: "Gauche"],
        "Mijloc": [.en: "Middle", .de: "Mitte", .fr: "Centre"],
        "Dreapta": [.en: "Right", .de: "Rechts", .fr: "Droite"],
        "Automat (din evoluția valorii)": [.en: "Automatic (from how the value changes)", .de: "Automatisch (aus dem Werteverlauf)", .fr: "Automatique (selon l’évolution de la valeur)"],
        "Senzor de stare": [.en: "State sensor", .de: "Statussensor", .fr: "Capteur d’état"],
        "Senzor de putere (W)": [.en: "Power sensor (W)", .de: "Leistungssensor (W)", .fr: "Capteur de puissance (W)"],
        "se încarcă": [.en: "charging", .de: "lädt", .fr: "en charge"],
        "se descarcă": [.en: "discharging", .de: "entlädt", .fr: "en décharge"],
        "în repaus": [.en: "idle", .de: "im Ruhezustand", .fr: "au repos"],
        "Potcoavă": [.en: "Horseshoe", .de: "Hufeisen", .fr: "Fer à cheval"],
        "Bară verticală": [.en: "Vertical bar", .de: "Vertikaler Balken", .fr: "Barre verticale"],
        "Bară orizontală": [.en: "Horizontal bar", .de: "Horizontaler Balken", .fr: "Barre horizontale"],
        "Numai text": [.en: "Text only", .de: "Nur Text", .fr: "Texte seul"],
        "Indicator cu ac": [.en: "Needle gauge", .de: "Zeigerinstrument", .fr: "Jauge à aiguille"],
        "din cardul Gauge din HA": [.en: "from the HA Gauge card", .de: "aus der Gauge-Karte in HA", .fr: "de la carte Gauge de HA"],
        "din atributele entității în HA": [.en: "from the entity attributes in HA", .de: "aus den Entitätsattributen in HA", .fr: "des attributs de l’entité dans HA"],
        "pentru procente (0–100)": [.en: "for percentages (0–100)", .de: "für Prozentwerte (0–100)", .fr: "pour les pourcentages (0–100)"],
        "Automat": [.en: "Automatic", .de: "Automatisch", .fr: "Automatique"],
        "Casă": [.en: "Home", .de: "Haus", .fr: "Maison"],
        "Mașină": [.en: "Car", .de: "Auto", .fr: "Voiture"],
        "Baterie": [.en: "Battery", .de: "Batterie", .fr: "Batterie"],
        "Putere": [.en: "Power", .de: "Leistung", .fr: "Puissance"],
        "Priză": [.en: "Plug", .de: "Steckdose", .fr: "Prise"],
        "Soare": [.en: "Sun", .de: "Sonne", .fr: "Soleil"],
        "Temperatură": [.en: "Temperature", .de: "Temperatur", .fr: "Température"],
        "Umiditate": [.en: "Humidity", .de: "Luftfeuchtigkeit", .fr: "Humidité"],
        "Apă": [.en: "Water", .de: "Wasser", .fr: "Eau"],
        "Gaz / foc": [.en: "Gas / fire", .de: "Gas / Feuer", .fr: "Gaz / feu"],
        "Ventilator": [.en: "Fan", .de: "Ventilator", .fr: "Ventilateur"],
        "Lumină": [.en: "Light", .de: "Licht", .fr: "Lumière"],
        "Eco": [.en: "Eco", .de: "Eco", .fr: "Éco"],
        "Rețea": [.en: "Network", .de: "Netzwerk", .fr: "Réseau"],
        "Mișcare": [.en: "Motion", .de: "Bewegung", .fr: "Mouvement"],
        "Salvat · indisponibil acum": [.en: "Saved · currently unavailable", .de: "Gespeichert · derzeit nicht verfügbar", .fr: "Enregistré · indisponible pour le moment"],
        "Caută după nume sau ID (ex. „inverter state”)…": [.en: "Search by name or ID (e.g. “inverter state”)…", .de: "Nach Name oder ID suchen (z. B. „inverter state“)…", .fr: "Rechercher par nom ou ID (ex. « inverter state »)…"],
        "Sugestii": [.en: "Suggestions", .de: "Vorschläge", .fr: "Suggestions"],
        "Toate (%@)": [.en: "All (%@)", .de: "Alle (%@)", .fr: "Toutes (%@)"],
        "Rezultate (%@)": [.en: "Results (%@)", .de: "Ergebnisse (%@)", .fr: "Résultats (%@)"],
        "Încă %@… scrie mai mult ca să restrângi.": [.en: "%@ more… type more to narrow down.", .de: "Noch %@… tippe mehr, um einzugrenzen.", .fr: "Encore %@… tapez davantage pour affiner."],
        "Golește alegerea": [.en: "Clear selection", .de: "Auswahl löschen", .fr: "Effacer la sélection"],
        "Configurează conexiunea la casa ta.": [.en: "Set up the connection to your home.", .de: "Richte die Verbindung zu deinem Zuhause ein.", .fr: "Configurez la connexion à votre maison."],
        "Se încarcă senzorii…": [.en: "Loading sensors…", .de: "Sensoren werden geladen…", .fr: "Chargement des capteurs…"],
        "Test": [.en: "Test", .de: "Test", .fr: "Test"],
        "Aceasta este o notificare de test din HassNotch. Dacă textul nu încape, se derulează de la stânga la dreapta.": [.en: "This is a test notification from HassNotch. If the text doesn’t fit, it scrolls from left to right.", .de: "Dies ist eine Testmitteilung von HassNotch. Wenn der Text nicht passt, läuft er von links nach rechts durch.", .fr: "Ceci est une notification de test de HassNotch. Si le texte ne tient pas, il défile de gauche à droite."],
        "Home Assistant a refuzat tokenul pentru conexiunea în timp real.": [.en: "Home Assistant rejected the token for the real-time connection.", .de: "Home Assistant hat das Token für die Echtzeitverbindung abgelehnt.", .fr: "Home Assistant a refusé le jeton pour la connexion en temps réel."],
        "Home Assistant nu permite citirea notificărilor cu acest token (e nevoie de un utilizator administrator).": [.en: "Home Assistant doesn’t allow reading notifications with this token (an administrator user is required).", .de: "Home Assistant erlaubt mit diesem Token kein Lesen von Mitteilungen (ein Administratorkonto ist erforderlich).", .fr: "Home Assistant ne permet pas de lire les notifications avec ce jeton (un utilisateur administrateur est requis)."],
        "Ascult notificările din Home Assistant.": [.en: "Listening for Home Assistant notifications.", .de: "Empfange Mitteilungen von Home Assistant.", .fr: "À l’écoute des notifications de Home Assistant."],
        "În timp real · %@ entități urmărite": [.en: "Real time · %@ entities tracked", .de: "Echtzeit · %@ Entitäten überwacht", .fr: "Temps réel · %@ entités suivies"],
        "Home Assistant a refuzat tokenul pentru citirea dashboard-urilor.": [.en: "Home Assistant rejected the token for reading dashboards.", .de: "Home Assistant hat das Token zum Lesen der Dashboards abgelehnt.", .fr: "Home Assistant a refusé le jeton pour la lecture des tableaux de bord."],
        "Nu am găsit carduri Gauge cu min/max în dashboard-uri.": [.en: "No Gauge cards with min/max found in the dashboards.", .de: "Keine Gauge-Karten mit Min/Max in den Dashboards gefunden.", .fr: "Aucune carte Gauge avec min/max trouvée dans les tableaux de bord."],
        "Intervale preluate din %@ carduri Gauge (%@ dashboard-uri).": [.en: "Ranges taken from %@ Gauge cards (%@ dashboards).", .de: "Bereiche aus %@ Gauge-Karten übernommen (%@ Dashboards).", .fr: "Plages reprises de %@ cartes Gauge (%@ tableaux de bord)."],
        "Nu am putut citi dashboard-urile. Folosesc ultimele intervale salvate.": [.en: "Couldn’t read the dashboards. Using the last saved ranges.", .de: "Dashboards konnten nicht gelesen werden. Die zuletzt gespeicherten Bereiche werden verwendet.", .fr: "Impossible de lire les tableaux de bord. Utilisation des dernières plages enregistrées."],
        "Nu pot citi senzorii. Verifică conexiunea și tokenul.": [.en: "Can’t read the sensors. Check the connection and the token.", .de: "Sensoren können nicht gelesen werden. Prüfe Verbindung und Token.", .fr: "Impossible de lire les capteurs. Vérifiez la connexion et le jeton."],
        "%@ entități citite din Home Assistant": [.en: "%@ entities read from Home Assistant", .de: "%@ Entitäten aus Home Assistant gelesen", .fr: "%@ entités lues depuis Home Assistant"],
        "Date indisponibile · reîncerc automat": [.en: "Data unavailable · retrying automatically", .de: "Daten nicht verfügbar · neuer Versuch automatisch", .fr: "Données indisponibles · nouvel essai automatique"],
        "Introdu adresa de bază, de exemplu http://homeassistant.local:8123, fără calea dashboardului.": [.en: "Enter the base address, e.g. http://homeassistant.local:8123, without the dashboard path.", .de: "Gib die Basisadresse ein, z. B. http://homeassistant.local:8123, ohne den Dashboard-Pfad.", .fr: "Saisissez l’adresse de base, par ex. http://homeassistant.local:8123, sans le chemin du tableau de bord."],
        "Introdu un token de acces pentru acest server.": [.en: "Enter an access token for this server.", .de: "Gib ein Zugriffstoken für diesen Server ein.", .fr: "Saisissez un jeton d’accès pour ce serveur."],
        "Verific conexiunea…": [.en: "Checking the connection…", .de: "Verbindung wird geprüft…", .fr: "Vérification de la connexion…"],
        "Token invalid sau acces refuzat. Verifică tokenul în profilul Home Assistant.": [.en: "Invalid token or access denied. Check the token in your Home Assistant profile.", .de: "Ungültiges Token oder Zugriff verweigert. Prüfe das Token in deinem Home-Assistant-Profil.", .fr: "Jeton invalide ou accès refusé. Vérifiez le jeton dans votre profil Home Assistant."],
        "Serverul redirecționează cererea. Introdu adresa finală Home Assistant.": [.en: "The server redirects the request. Enter the final Home Assistant address.", .de: "Der Server leitet die Anfrage um. Gib die endgültige Home-Assistant-Adresse ein.", .fr: "Le serveur redirige la requête. Saisissez l’adresse finale de Home Assistant."],
        "Serverul a răspuns cu eroarea HTTP %@.": [.en: "The server responded with HTTP error %@.", .de: "Der Server antwortete mit HTTP-Fehler %@.", .fr: "Le serveur a répondu avec l’erreur HTTP %@."],
        "Conexiunea funcționează, dar tokenul nu a putut fi salvat în Keychain. Încearcă din nou.": [.en: "The connection works, but the token couldn’t be saved to the Keychain. Try again.", .de: "Die Verbindung funktioniert, aber das Token konnte nicht im Schlüsselbund gespeichert werden. Versuche es erneut.", .fr: "La connexion fonctionne, mais le jeton n’a pas pu être enregistré dans le trousseau. Réessayez."],
        "Conexiune verificată. Configurarea a fost salvată.": [.en: "Connection verified. The configuration has been saved.", .de: "Verbindung geprüft. Die Konfiguration wurde gespeichert.", .fr: "Connexion vérifiée. La configuration a été enregistrée."],
        "Adresa nu a returnat configurația Home Assistant. Verifică serverul.": [.en: "The address didn’t return a Home Assistant configuration. Check the server.", .de: "Die Adresse hat keine Home-Assistant-Konfiguration geliefert. Prüfe den Server.", .fr: "L’adresse n’a pas renvoyé de configuration Home Assistant. Vérifiez le serveur."],
        "Nu pot contacta Home Assistant. Verifică adresa, rețeaua și dacă serverul este pornit.": [.en: "Can’t reach Home Assistant. Check the address, the network and whether the server is running.", .de: "Home Assistant ist nicht erreichbar. Prüfe Adresse, Netzwerk und ob der Server läuft.", .fr: "Impossible de joindre Home Assistant. Vérifiez l’adresse, le réseau et que le serveur est démarré."],
        "Răspuns Home Assistant invalid.": [.en: "Invalid Home Assistant response.", .de: "Ungültige Antwort von Home Assistant.", .fr: "Réponse de Home Assistant invalide."],
        "Da": [.en: "Yes", .de: "Ja", .fr: "Oui"],
        "Nu": [.en: "No", .de: "Nein", .fr: "Non"],
        "Setări…": [.en: "Settings…", .de: "Einstellungen…", .fr: "Réglages…"],
        "Informații afișate…": [.en: "Displayed information…", .de: "Angezeigte Informationen…", .fr: "Informations affichées…"],
        "Închide HassNotch": [.en: "Quit HassNotch", .de: "HassNotch beenden", .fr: "Quitter HassNotch"],
        "Setări · HassNotch": [.en: "Settings · HassNotch", .de: "Einstellungen · HassNotch", .fr: "Réglages · HassNotch"],
        "Apasă rotița ca să alegi ce se afișează": [.en: "Click the gear to choose what’s shown", .de: "Klicke auf das Zahnrad, um die Anzeige zu wählen", .fr: "Cliquez sur la roue dentée pour choisir l’affichage"],
        "Setări": [.en: "Settings", .de: "Einstellungen", .fr: "Réglages"],
        "Conectat la HA": [.en: "Connected to HA", .de: "Mit HA verbunden", .fr: "Connecté à HA"],
        "Neconectat la HA": [.en: "Not connected to HA", .de: "Nicht mit HA verbunden", .fr: "Non connecté à HA"],
        "Notch clasic": [.en: "Classic notch", .de: "Klassischer Notch", .fr: "Encoche classique"],
        "Se lipește de marginea de sus a ecranului, peste notch-ul fizic. Arată natural pe MacBook Air 13″ (M2, 2022) și mai noi, MacBook Air 15″ (2023 și mai noi), MacBook Pro 14″ și 16″ (2021, M1 Pro/Max) și mai noi.": [.en: "Sticks to the top edge of the screen, over the physical notch. Looks natural on MacBook Air 13″ (M2, 2022) and newer, MacBook Air 15″ (2023 and newer), MacBook Pro 14″ and 16″ (2021, M1 Pro/Max) and newer.", .de: "Haftet am oberen Bildschirmrand über dem physischen Notch. Wirkt natürlich auf MacBook Air 13″ (M2, 2022) und neuer, MacBook Air 15″ (2023 und neuer), MacBook Pro 14″ und 16″ (2021, M1 Pro/Max) und neuer.", .fr: "Se colle au bord supérieur de l’écran, par-dessus l’encoche physique. Paraît naturelle sur MacBook Air 13″ (M2, 2022) et plus récents, MacBook Air 15″ (2023 et plus récents), MacBook Pro 14″ et 16″ (2021, M1 Pro/Max) et plus récents."],
        "O bulină neagră cât bara de meniu, care se extinde când treci cu mouse-ul peste ea. Potrivită pentru Mac mini, Mac Studio, iMac, monitoare externe și MacBook-uri fără notch.": [.en: "A black pill the height of the menu bar that expands when you hover over it. Suited to Mac mini, Mac Studio, iMac, external displays and MacBooks without a notch.", .de: "Eine schwarze Kapsel in Höhe der Menüleiste, die sich beim Darüberfahren mit der Maus ausdehnt. Geeignet für Mac mini, Mac Studio, iMac, externe Monitore und MacBooks ohne Notch.", .fr: "Une pastille noire de la hauteur de la barre des menus, qui s’agrandit au survol de la souris. Adaptée aux Mac mini, Mac Studio, iMac, écrans externes et MacBook sans encoche."],
        "Rolă (pompă de benzină)": [.en: "Rolling (petrol pump)", .de: "Walze (Zapfsäule)", .fr: "Rouleau (pompe à essence)"],
        "Simplă": [.en: "Simple", .de: "Einfach", .fr: "Simple"],
        "Tip notch": [.en: "Notch type", .de: "Notch-Typ", .fr: "Type d’encoche"],
        "Alege cum arată insula din partea de sus a ecranului. Schimbarea se aplică imediat.": [.en: "Choose how the island at the top of the screen looks. Changes apply immediately.", .de: "Wähle, wie die Insel oben am Bildschirm aussieht. Änderungen werden sofort übernommen.", .fr: "Choisissez l’apparence de l’îlot en haut de l’écran. Les changements s’appliquent immédiatement."],
        "Vibrație în trackpad la deschiderea insulei": [.en: "Trackpad vibration when the island opens", .de: "Trackpad-Vibration beim Öffnen der Insel", .fr: "Vibration du trackpad à l’ouverture de l’îlot"],
        "Merge cu trackpadurile Force Touch (MacBook, Magic Trackpad). Cu mouse-ul nu se simte nimic.": [.en: "Works with Force Touch trackpads (MacBook, Magic Trackpad). Nothing is felt with a mouse.", .de: "Funktioniert mit Force-Touch-Trackpads (MacBook, Magic Trackpad). Mit einer Maus ist nichts zu spüren.", .fr: "Fonctionne avec les trackpads Force Touch (MacBook, Magic Trackpad). Rien n’est ressenti avec une souris."],
        "Testează vibrația": [.en: "Test vibration", .de: "Vibration testen", .fr: "Tester la vibration"],
        "Ține apăsat pe buton: vibrația vine cât timp degetul apasă trackpadul.": [.en: "Press and hold the button: the vibration comes while your finger presses the trackpad.", .de: "Halte die Taste gedrückt: Die Vibration kommt, während dein Finger auf das Trackpad drückt.", .fr: "Maintenez le bouton enfoncé : la vibration arrive pendant que votre doigt appuie sur le trackpad."],
        "Intensitate": [.en: "Strength", .de: "Stärke", .fr: "Intensité"],
        "Fină": [.en: "Subtle", .de: "Fein", .fr: "Légère"],
        "Medie": [.en: "Medium", .de: "Mittel", .fr: "Moyenne"],
        "Puternică": [.en: "Strong", .de: "Stark", .fr: "Forte"],
        "Foarte puternică": [.en: "Very strong", .de: "Sehr stark", .fr: "Très forte"],
        "Apasă cu trackpadul: ar trebui să simți o vibrație scurtă, separată de clic.": [.en: "Click with the trackpad: you should feel a short vibration, separate from the click.", .de: "Klicke mit dem Trackpad: Du solltest eine kurze Vibration spüren, getrennt vom Klick.", .fr: "Cliquez avec le trackpad : vous devriez sentir une brève vibration, distincte du clic."],
        "Ecranul principal are notch fizic: Notch clasic arată cel mai natural.": [.en: "The main display has a physical notch: Classic notch looks most natural.", .de: "Der Hauptbildschirm hat einen physischen Notch: Klassischer Notch wirkt am natürlichsten.", .fr: "L’écran principal a une encoche physique : l’encoche classique paraît la plus naturelle."],
        "Ecranul principal nu are notch fizic: Dynamic Island arată cel mai natural.": [.en: "The main display has no physical notch: Dynamic Island looks most natural.", .de: "Der Hauptbildschirm hat keinen physischen Notch: Dynamic Island wirkt am natürlichsten.", .fr: "L’écran principal n’a pas d’encoche physique : Dynamic Island paraît la plus naturelle."],
        "Notificări": [.en: "Notifications", .de: "Mitteilungen", .fr: "Notifications"],
        "Orice notificare trimisă din Home Assistant spre telefon (notify.mobile_app_…) apare și pe insulă: Dynamic Island se lățește de două ori, notch-ul crește în jos, iar textul lung se derulează.": [.en: "Any notification sent from Home Assistant to a phone (notify.mobile_app_…) also appears on the island: Dynamic Island doubles its width, the notch grows downwards, and long text scrolls.", .de: "Jede Mitteilung, die Home Assistant an ein Telefon sendet (notify.mobile_app_…), erscheint auch auf der Insel: Dynamic Island wird doppelt so breit, der Notch wächst nach unten und langer Text läuft durch.", .fr: "Toute notification envoyée par Home Assistant à un téléphone (notify.mobile_app_…) apparaît aussi sur l’îlot : Dynamic Island double de largeur, l’encoche s’agrandit vers le bas et le texte long défile."],
        "Afișează notificările din Home Assistant pe insulă": [.en: "Show Home Assistant notifications on the island", .de: "Home-Assistant-Mitteilungen auf der Insel anzeigen", .fr: "Afficher les notifications Home Assistant sur l’îlot"],
        "Durată minimă pe ecran": [.en: "Minimum time on screen", .de: "Mindestanzeigedauer", .fr: "Durée minimale à l’écran"],
        "Textul lung rămâne cât să se poată derula o dată complet, chiar dacă durează mai mult.": [.en: "Long text stays long enough to scroll through once completely, even if that takes longer.", .de: "Langer Text bleibt so lange, bis er einmal vollständig durchgelaufen ist, auch wenn das länger dauert.", .fr: "Le texte long reste affiché le temps de défiler une fois entièrement, même si cela prend plus de temps."],
        "Sunet": [.en: "Sound", .de: "Ton", .fr: "Son"],
        "Fără sunet": [.en: "No sound", .de: "Kein Ton", .fr: "Aucun son"],
        "Ascultă sunetul": [.en: "Play the sound", .de: "Ton anhören", .fr: "Écouter le son"],
        "Atrage atenția: insula crește și pe verticală ~3,5 s, apoi revine": [.en: "Get attention: the island also grows vertically for ~3.5 s, then returns", .de: "Aufmerksamkeit wecken: Die Insel wächst ~3,5 s auch in der Höhe und kehrt dann zurück", .fr: "Attirer l’attention : l’îlot s’agrandit aussi en hauteur ~3,5 s, puis revient"],
        "Pentru ce dispozitive": [.en: "For which devices", .de: "Für welche Geräte", .fr: "Pour quels appareils"],
        "Încă n-a sosit nicio notificare. Lista se completează singură la prima notificare trimisă din HA; implicit se preiau toate cele spre aplicația mobilă (mobile_app_…).": [.en: "No notification has arrived yet. The list fills in by itself with the first notification sent from HA; by default, all those sent to the mobile app (mobile_app_…) are included.", .de: "Es ist noch keine Mitteilung eingegangen. Die Liste füllt sich bei der ersten von HA gesendeten Mitteilung von selbst; standardmäßig werden alle an die mobile App (mobile_app_…) übernommen.", .fr: "Aucune notification n’est encore arrivée. La liste se remplit d’elle-même à la première notification envoyée par HA ; par défaut, toutes celles envoyées à l’application mobile (mobile_app_…) sont reprises."],
        "Trimite o notificare de test": [.en: "Send a test notification", .de: "Testmitteilung senden", .fr: "Envoyer une notification de test"],
        "Ultimele notificări": [.en: "Recent notifications", .de: "Letzte Mitteilungen", .fr: "Dernières notifications"],
        "Poziționare": [.en: "Position", .de: "Position", .fr: "Position"],
        "Poziționarea e disponibilă doar pentru Dynamic Island. Notch-ul clasic stă mereu peste camera fizică a laptopului, deci nu are sens să fie mutat.": [.en: "Positioning is only available for Dynamic Island. The classic notch always sits over the laptop’s physical camera, so moving it makes no sense.", .de: "Die Positionierung ist nur für Dynamic Island verfügbar. Der klassische Notch sitzt immer über der physischen Kamera des Laptops, daher ergibt ein Verschieben keinen Sinn.", .fr: "Le positionnement n’est disponible que pour Dynamic Island. L’encoche classique se trouve toujours au-dessus de la caméra physique de l’ordinateur portable ; la déplacer n’a donc pas de sens."],
        "Mută Dynamic Island unde îți convine. Modificările se văd imediat; implicit stă centrată, sus.": [.en: "Move Dynamic Island wherever suits you. Changes are visible immediately; by default it sits centred at the top.", .de: "Verschiebe Dynamic Island, wohin du möchtest. Änderungen sind sofort sichtbar; standardmäßig sitzt sie zentriert oben.", .fr: "Déplacez Dynamic Island où vous le souhaitez. Les changements sont visibles immédiatement ; par défaut, elle est centrée en haut."],
        "Monitor": [.en: "Display", .de: "Bildschirm", .fr: "Écran"],
        "Alege monitorul pe care apare HassNotch. Rămâne mereu acolo, indiferent pe ce ecran lucrezi când pornește aplicația.": [.en: "Choose the display where HassNotch appears. It always stays there, no matter which screen you are working on when the app starts.", .de: "Wähle den Bildschirm, auf dem HassNotch erscheint. Es bleibt immer dort, egal auf welchem Bildschirm du arbeitest, wenn die App startet.", .fr: "Choisissez l’écran sur lequel HassNotch apparaît. Il y reste toujours, quel que soit l’écran sur lequel vous travaillez au démarrage de l’app."],
        "Monitorul principal (cel cu bara de meniu)": [.en: "Main display (the one with the menu bar)", .de: "Hauptbildschirm (der mit der Menüleiste)", .fr: "Écran principal (celui avec la barre des menus)"],
        "principal": [.en: "main", .de: "Haupt", .fr: "principal"],
        "cu notch": [.en: "with notch", .de: "mit Notch", .fr: "avec encoche"],
        "Ai un singur monitor conectat, deci HassNotch apare pe el. Alegerea devine activă când conectezi încă un monitor.": [.en: "You have only one display connected, so HassNotch appears on it. The choice becomes available when you connect another display.", .de: "Es ist nur ein Bildschirm angeschlossen, daher erscheint HassNotch dort. Die Auswahl wird aktiv, sobald du einen weiteren Bildschirm anschließt.", .fr: "Un seul écran est connecté, HassNotch y apparaît donc. Le choix devient disponible lorsque vous branchez un autre écran."],
        "Dacă monitorul ales e deconectat, HassNotch trece pe monitorul principal și revine singur când îl reconectezi.": [.en: "If the chosen display is disconnected, HassNotch moves to the main display and returns by itself when you reconnect it.", .de: "Wird der gewählte Bildschirm getrennt, wechselt HassNotch auf den Hauptbildschirm und kehrt von selbst zurück, sobald du ihn wieder anschließt.", .fr: "Si l’écran choisi est déconnecté, HassNotch passe sur l’écran principal et y revient tout seul quand vous le rebranchez."],
        "Monitorul ales nu e conectat acum.": [.en: "The chosen display is not connected right now.", .de: "Der gewählte Bildschirm ist gerade nicht angeschlossen.", .fr: "L’écran choisi n’est pas connecté pour le moment."],
        "Ecran": [.en: "Display", .de: "Bildschirm", .fr: "Écran"],
        "Ecranul principal": [.en: "Main display", .de: "Hauptbildschirm", .fr: "Écran principal"],
        "Orizontal": [.en: "Horizontal", .de: "Horizontal", .fr: "Horizontal"],
        "Centru": [.en: "Centre", .de: "Mitte", .fr: "Centre"],
        "Distanța de marginea de sus": [.en: "Distance from the top edge", .de: "Abstand zum oberen Rand", .fr: "Distance du bord supérieur"],
        "lipită sus": [.en: "at the top", .de: "ganz oben", .fr: "collée en haut"],
        "La 0 stă în bara de meniu; cu valori mai mari coboară sub ea.": [.en: "At 0 it sits in the menu bar; higher values move it below.", .de: "Bei 0 sitzt sie in der Menüleiste; höhere Werte verschieben sie darunter.", .fr: "À 0, elle est dans la barre des menus ; des valeurs plus élevées la font descendre en dessous."],
        "Resetează la poziția implicită": [.en: "Reset to default position", .de: "Auf Standardposition zurücksetzen", .fr: "Rétablir la position par défaut"],
        "centrată": [.en: "centred", .de: "zentriert", .fr: "centrée"],
        "%@ pt la stânga": [.en: "%@ pt to the left", .de: "%@ pt nach links", .fr: "%@ pt à gauche"],
        "%@ pt la dreapta": [.en: "%@ pt to the right", .de: "%@ pt nach rechts", .fr: "%@ pt à droite"],
        "Casa ta, în HassNotch": [.en: "Your home, in HassNotch", .de: "Dein Zuhause in HassNotch", .fr: "Votre maison, dans HassNotch"],
        "Conectează Home Assistant pentru a începe.": [.en: "Connect Home Assistant to get started.", .de: "Verbinde Home Assistant, um loszulegen.", .fr: "Connectez Home Assistant pour commencer."],
        "Adresa Home Assistant": [.en: "Home Assistant address", .de: "Home-Assistant-Adresse", .fr: "Adresse de Home Assistant"],
        "Adresa serverului, fără /lovelace sau /dashboard.": [.en: "Server address, without /lovelace or /dashboard.", .de: "Serveradresse, ohne /lovelace oder /dashboard.", .fr: "Adresse du serveur, sans /lovelace ni /dashboard."],
        "Pe acest Mac": [.en: "On this Mac", .de: "Auf diesem Mac", .fr: "Sur ce Mac"],
        "Token de acces": [.en: "Access token", .de: "Zugriffstoken", .fr: "Jeton d’accès"],
        "Token salvat · lasă gol pentru a-l păstra": [.en: "Token saved · leave empty to keep it", .de: "Token gespeichert · leer lassen, um es zu behalten", .fr: "Jeton enregistré · laissez vide pour le conserver"],
        "Lipește tokenul aici": [.en: "Paste the token here", .de: "Token hier einfügen", .fr: "Collez le jeton ici"],
        "Păstrat în siguranță în Keychain pe acest Mac.": [.en: "Stored securely in the Keychain on this Mac.", .de: "Sicher im Schlüsselbund auf diesem Mac gespeichert.", .fr: "Conservé en sécurité dans le trousseau de ce Mac."],
        "De unde iau tokenul?": [.en: "Where do I get the token?", .de: "Woher bekomme ich das Token?", .fr: "Où obtenir le jeton ?"],
        "În Home Assistant, deschide profilul tău → Securitate → Tokenuri de acces de lungă durată. Creează un token numit HassNotch și lipește-l în câmpul de mai sus.": [.en: "In Home Assistant, open your profile → Security → Long-lived access tokens. Create a token named HassNotch and paste it into the field above.", .de: "Öffne in Home Assistant dein Profil → Sicherheit → Langlebige Zugriffstoken. Erstelle ein Token namens HassNotch und füge es oben ein.", .fr: "Dans Home Assistant, ouvrez votre profil → Sécurité → Jetons d’accès longue durée. Créez un jeton nommé HassNotch et collez-le dans le champ ci-dessus."],
        "Deschide profilul Home Assistant": [.en: "Open Home Assistant profile", .de: "Home-Assistant-Profil öffnen", .fr: "Ouvrir le profil Home Assistant"],
        "%@ · HA %@ · verificat la %@": [.en: "%@ · HA %@ · checked at %@", .de: "%@ · HA %@ · geprüft um %@", .fr: "%@ · HA %@ · vérifié à %@"],
        "Conexiune directă cu serverul tău.": [.en: "Direct connection to your server.", .de: "Direkte Verbindung zu deinem Server.", .fr: "Connexion directe à votre serveur."],
        "Se conectează…": [.en: "Connecting…", .de: "Verbinde…", .fr: "Connexion…"],
        "Salvează și conectează": [.en: "Save and connect", .de: "Speichern und verbinden", .fr: "Enregistrer et se connecter"],
        "Conectare la Home Assistant": [.en: "Home Assistant connection", .de: "Verbindung zu Home Assistant", .fr: "Connexion à Home Assistant"],
        "Unde apare aplicația": [.en: "Where the app appears", .de: "Wo die App erscheint", .fr: "Où l’application apparaît"],
        "Doar în bara de meniu": [.en: "Menu bar only", .de: "Nur in der Menüleiste", .fr: "Uniquement dans la barre des menus"],
        "În bara de meniu și în Dock": [.en: "Menu bar and Dock", .de: "Menüleiste und Dock", .fr: "Barre des menus et Dock"],
        "Fără iconiță în Dock: aplicația se deschide din iconița din bara de meniu sau din rotița de pe insulă.": [.en: "Without a Dock icon, open the app from its menu bar icon or the gear on the island.", .de: "Ohne Dock-Symbol öffnest du die App über ihr Menüleistensymbol oder das Zahnrad auf der Insel.", .fr: "Sans icône dans le Dock, ouvrez l’application depuis son icône dans la barre des menus ou la roue dentée de l’îlot."],
        "Limbă": [.en: "Language", .de: "Sprache", .fr: "Langue"],
        "Buy me a beer": [.en: "Buy me a beer", .de: "Spendier mir ein Bier", .fr: "Offrez-moi une bière"],
        "HassNotch este gratuit și open source. Dacă îți este util și vrei să susții dezvoltarea lui, poți să-mi faci cinste cu o bere. Mulțumesc!": [.en: "HassNotch is free and open source. If you find it useful and want to support its development, you can buy me a beer. Thank you!", .de: "HassNotch ist kostenlos und Open Source. Wenn es dir nützt und du die Entwicklung unterstützen möchtest, kannst du mir ein Bier spendieren. Danke!", .fr: "HassNotch est gratuit et open source. S’il vous est utile et que vous souhaitez soutenir son développement, vous pouvez m’offrir une bière. Merci !"],
        "Fiecare donație ajută la noi funcții, reparații și la menținerea aplicației gratuite pentru toată lumea.": [.en: "Every donation helps with new features, fixes and keeping the app free for everyone.", .de: "Jede Spende hilft bei neuen Funktionen, Fehlerbehebungen und dabei, die App für alle kostenlos zu halten.", .fr: "Chaque don aide à ajouter des fonctions, corriger des problèmes et garder l’application gratuite pour tous."],
        "Idei sau probleme?": [.en: "Ideas or issues?", .de: "Ideen oder Probleme?", .fr: "Des idées ou des problèmes ?"],
        "Ai găsit o problemă sau vrei o funcție nouă? Scrie-mi, citesc fiecare mesaj.": [.en: "Found a bug or want a new feature? Write to me, I read every message.", .de: "Einen Fehler gefunden oder eine neue Funktion gewünscht? Schreib mir, ich lese jede Nachricht.", .fr: "Vous avez trouvé un bug ou souhaitez une nouvelle fonction ? Écrivez-moi, je lis chaque message."],
        "Cumpără-mi o bere": [.en: "Buy me a beer", .de: "Spendier mir ein Bier", .fr: "Offrez-moi une bière"],
        "Proiectul pe GitHub": [.en: "Project on GitHub", .de: "Projekt auf GitHub", .fr: "Projet sur GitHub"],
        "Pagina de donații va fi disponibilă în curând.": [.en: "The donation page will be available soon.", .de: "Die Spendenseite ist bald verfügbar.", .fr: "La page de dons sera bientôt disponible."],
        "Alte moduri de a ajuta: dă o stea proiectului pe GitHub, raportează problemele găsite sau recomandă HassNotch altor utilizatori Home Assistant.": [.en: "Other ways to help: star the project on GitHub, report any issues you find, or recommend HassNotch to other Home Assistant users.", .de: "Andere Möglichkeiten zu helfen: Gib dem Projekt einen Stern auf GitHub, melde gefundene Probleme oder empfiehl HassNotch anderen Home-Assistant-Nutzern.", .fr: "Autres façons d’aider : mettez une étoile au projet sur GitHub, signalez les problèmes rencontrés ou recommandez HassNotch à d’autres utilisateurs de Home Assistant."],
        "Alege limba aplicației. Schimbarea se aplică imediat.": [.en: "Choose the app language. The change applies immediately.", .de: "Wähle die Sprache der App. Die Änderung gilt sofort.", .fr: "Choisissez la langue de l’application. Le changement s’applique immédiatement."],
    ]
}

/// The text translated into the chosen language. Arguments replace each %@ in order.
nonisolated func L(_ key: String, _ args: Any...) -> String {
    let text = Localization.text(key)
    guard !args.isEmpty else { return text }
    var result = ""
    var remaining = args.makeIterator()
    let parts = text.components(separatedBy: "%@")
    for (index, part) in parts.enumerated() {
        result += part
        if index < parts.count - 1 { result += remaining.next().map { "\($0)" } ?? "" }
    }
    return result
}

/// The "Language" category in Settings.
struct LanguageSettingsView: View {
    @ObservedObject private var settings = NotchSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Limbă")).font(.title2.bold())
            Text(L("Alege limba aplicației. Schimbarea se aplică imediat."))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    Button { settings.language = language } label: {
                        HStack(spacing: 12) {
                            Text(language.flag).font(.title2)
                            Text(language.nativeName).font(.body)
                            Spacer()
                            Image(systemName: settings.language == language ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(settings.language == language ? Color.accentColor : Color.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.quaternary.opacity(settings.language == language ? 0.7 : 0.3),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 360)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
