Skonfiguruj podpisywanie release'u zgodnie z oficjalną dokumentacją Flutter
(docs.flutter.dev/deployment/android), wariant Kotlin DSL:

1. W android/app/build.gradle.kts:
   - dodaj importy java.util.Properties i java.io.FileInputStream
   - przed blokiem android { } wczytaj rootProject.file("key.properties")
     do obiektu Properties (tylko jeśli plik istnieje)
   - dodaj signingConfigs { create("release") { ... } } czytający keyAlias,
     keyPassword, storeFile i storePassword z tych properties
   - w buildTypes.release podmień signingConfig z debug na release
     i usuń komentarz TODO o kluczach debug

2. Upewnij się, że .gitignore (główny i/lub android/.gitignore) zawiera:
   android/key.properties
   *.jks
   *.keystore

3. NIE twórz pliku key.properties ani keystore'a — utworzyłem je sam.
   Nie wypisuj i nie loguj żadnych haseł.

4. Na koniec uruchom flutter build apk --release i sprawdź,
   czy build kończy się sukcesem.