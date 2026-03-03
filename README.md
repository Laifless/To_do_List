#  Hunter System — Setup Guide

App ispirata a **Solo Leveling** per tracciare allenamenti, quest giornaliere e avventure.

---

##  Dipendenze richieste

Nel `pubspec.yaml` hai già tutto. Lancia:

```bash
flutter pub get
```

---

##  Setup Notifiche

### Android

Il file `AndroidManifest.xml` nella cartella `android/app/src/main/` deve contenere i permessi già inclusi. Se non funziona, aggiungili manualmente nel tuo `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

Poi dentro `<application>`:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

### iOS

In `ios/Runner/Info.plist` aggiungi:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

---

##  Funzionalità implementate

###  Quest Log
-  **Daily quests** con checkbox e barrato animato
-  **Adventure quests**
-  **Reminder** con selettore orario (notifica locale)
-  Reset dailies manuale (bottone refresh in alto a destra)
-  Rimozione singola quest con icona ×

###  Dungeon (Palestra)
-  **Creazione scheda** con filtro per gruppo muscolare
-  **Aggiunta esercizi custom** (nome + gruppo muscolare)
-  Target serie configurabile per ogni esercizio
-  **Log set** con kg e reps
-  **Timer di recupero** integrato (60/90/120s + popup automatico dopo log)
-  **Storico pesi** per ogni esercizio con grafico a linea
-  **Record personale** evidenziato con 🏆
-  Progress bar per ogni scheda
-  Reset sessione (riparti da 0 senza perdere lo storico)

###  Status Window
-  **Level** calcolato su volume totale + quest completate
-  Volume totale sollevato (kg)
-  Dungeon completati
-  Quest totali / completate
-  Barra XP verso il prossimo livello

###  Persistenza
-  Tutti i dati salvati in locale con `shared_preferences`
-  Storico pesi persistente tra le sessioni
-  Esercizi custom salvati

---

##  Design
- Palette nera/ciano ispirata al System di Solo Leveling
- Font monospace stile terminale
- Effetti glow sui bordi e testo
- Animazioni sui checkbox e progress bar
- FAB con animazione glow pulsante

---

##  Struttura file

```
lib/
└── main.dart          ← tutto in un singolo file

pubspec.yaml
android/
└── AndroidManifest.xml   ← permessi notifiche
```

---

##  Avvio

```bash
flutter pub get
flutter run
```

> **Nota:** Le notifiche funzionano solo su dispositivo fisico o emulatore con Google Play.
