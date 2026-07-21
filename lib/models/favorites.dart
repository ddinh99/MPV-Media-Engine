// lib/models/favorites.dart

/// A hardcoded audio-hardware profile shown in the Favorites menu.
///
/// Unlike [Preset], a favorite is *only* a raw customFilter string - there's
/// no backing DspState, so it bypasses FilterBuilder/DynAudNormSettings
/// entirely and is sent to mpv verbatim. That means nothing here gets the
/// clamping DynAudNormSettings does for state-based presets; these strings
/// must be valid on their own (see filter_chain_validity_test.dart).
class FavoriteProfile {
  final String id;
  final String label;
  final String filter;

  const FavoriteProfile({required this.id, required this.label, required this.filter});
}

/// Ordered groups of favorites for the Favorites menu; a divider is drawn
/// before every group after the first.
final List<List<FavoriteProfile>> builtinFavoriteGroups = [
  [
    const FavoriteProfile(
      id: 'Promedia 2.1 Tweak Rev 4',
      label: '⭐ Promedia 2.1 Tweak Rev 4 (Incredible)',
      filter: '#af-add=lavfi=[dynaudnorm=f=500:g=31:p=0.7:m=5,pan=stereo|FL=0.68*FL+0.55*FC+0.30*BL+0.25*SL+0.30*LFE|FR=0.68*FR+0.55*FC+0.30*BR+0.25*SR+0.30*LFE,asplit=2[main][amb],[amb]highpass=f=220,lowpass=f=8500,aecho=0.25:0.40:24:0.35,aphaser=type=t:speed=0.1:decay=0.2,extrastereo=0.32[amb2],[main][amb2]amix=inputs=2:weights=1 0.75:normalize=0,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1|c0 f=130 w=50 g=-3.5 t=1|c1 f=130 w=50 g=-3.5 t=1|c0 f=250 w=70 g=+1.5 t=1|c1 f=250 w=70 g=+1.5 t=1|c0 f=1000 w=200 g=+1.8 t=1|c1 f=1000 w=200 g=+1.8 t=1|c0 f=1800 w=300 g=+2.0 t=1|c1 f=1800 w=300 g=+2.0 t=1|c0 f=2800 w=500 g=+3.5 t=1|c1 f=2800 w=500 g=+3.5 t=1|c0 f=3500 w=600 g=+2.0 t=1|c1 f=3500 w=600 g=+2.0 t=1|c0 f=5500 w=300 g=-2.0 t=1|c1 f=5500 w=300 g=-2.0 t=1|c0 f=10000 w=2000 g=+1.5 t=1|c1 f=10000 w=2000 g=+1.5 t=1,highshelf=f=5000:g=1.2:w=2000:t=1,acompressor=threshold=-20dB:ratio=2.5:attack=10:release=180:makeup=2dB,alimiter=limit=-0.5dB]',
    ),
    const FavoriteProfile(
      id: 'Promedia 2.1 Tweak Rev 4 (Alt)',
      label: '⭐ Promedia 2.1 Tweak Rev 4 (Best)',
      filter: '#af-add=lavfi=[dynaudnorm=f=250:g=31:p=0.95:m=8:c=1,pan=stereo|FL=0.68*FL+0.55*FC+0.30*BL+0.25*SL+0.30*LFE|FR=0.68*FR+0.55*FC+0.30*BR+0.25*SR+0.30*LFE,asplit=2[main][amb],[amb]highpass=f=220,lowpass=f=8500,aecho=0.25:0.40:24:0.35,aphaser=type=t:speed=0.1:decay=0.2,extrastereo=0.32[amb2],[main][amb2]amix=inputs=2:weights=1 0.75:normalize=0,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1|c0 f=130 w=50 g=-3.5 t=1|c1 f=130 w=50 g=-3.5 t=1|c0 f=250 w=70 g=+1.5 t=1|c1 f=250 w=70 g=+1.5 t=1|c0 f=1000 w=200 g=+1.8 t=1|c1 f=1000 w=200 g=+1.8 t=1|c0 f=1800 w=300 g=+2.0 t=1|c1 f=1800 w=300 g=+2.0 t=1|c0 f=2800 w=500 g=+3.5 t=1|c1 f=2800 w=500 g=+3.5 t=1|c0 f=3500 w=600 g=+2.0 t=1|c1 f=3500 w=600 g=+2.0 t=1|c0 f=5500 w=300 g=-2.0 t=1|c1 f=5500 w=300 g=-2.0 t=1|c0 f=10000 w=2000 g=+1.5 t=1|c1 f=10000 w=2000 g=+1.5 t=1,highshelf=f=5000:g=1.2:w=2000:t=1,acompressor=threshold=-20dB:ratio=2.5:attack=10:release=180:makeup=2dB,alimiter=limit=-0.5dB]',
    ),
  ],
  [
    const FavoriteProfile(
      id: 'Klipsch ProMedia 2.1 THX',
      label: '🔊 Klipsch ProMedia 2.1 THX',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.9,pan=stereo|FL=0.85*FL+0.5*FC+0.5*BL+0.5*LFE|FR=0.85*FR+0.5*FC+0.5*BR+0.5*LFE,anequalizer=c0 f=60 w=50 g=+4.5 t=1|c1 f=60 w=50 g=+4.5 t=1|c0 f=8000 w=2000 g=+2.5 t=1|c1 f=8000 w=2000 g=+2.5 t=1,acompressor=threshold=-18dB:ratio=3:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'Klipsch ProMedia 2.1 THX (Optimized)',
      label: '🔊 Klipsch ProMedia 2.1 THX (Optimized)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.9:c=1,pan=stereo|FL=0.85*FL+0.5*FC+0.5*BL+0.5*LFE|FR=0.85*FR+0.5*FC+0.5*BR+0.5*LFE,anequalizer=c0 f=45 w=40 g=+2.0 t=1|c1 f=45 w=40 g=+2.0 t=1|c0 f=130 w=60 g=-2.5 t=1|c1 f=130 w=60 g=-2.5 t=1|c0 f=3000 w=700 g=+2.0 t=1|c1 f=3000 w=700 g=+2.0 t=1|c0 f=5500 w=800 g=-1.0 t=1|c1 f=5500 w=800 g=-1.0 t=1|c0 f=9000 w=2500 g=+2.0 t=1|c1 f=9000 w=2500 g=+2.0 t=1,acompressor=threshold=-20dB:ratio=2.5:attack=10:release=180:makeup=2dB,alimiter=limit=-0.5dB]',
    ),
    const FavoriteProfile(
      id: 'Logitech Z906 5.1 Surround',
      label: '🔊 Logitech Z906 5.1 Surround',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31:p=0.9,pan=5.1|FL=FL|FR=FR|FC=FC+0.2*FL+0.2*FR|LFE=LFE+0.2*FC|BL=BL+0.2*SL|BR=BR+0.2*SR,anequalizer=c0 f=80 w=50 g=+3.0 t=1|c1 f=80 w=50 g=+3.0 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Logitech Z623 2.1 THX',
      label: '🔊 Logitech Z623 2.1 THX (Aggressive)',
      filter: '#af-add=lavfi=[dynaudnorm=f=250:g=31:p=0.85,pan=stereo|FL=0.7*FL+0.5*FC+0.6*LFE|FR=0.7*FR+0.5*FC+0.6*LFE,anequalizer=c0 f=60 w=50 g=+5.0 t=1|c1 f=60 w=50 g=+5.0 t=1|c0 f=2000 w=800 g=-1.5 t=1|c1 f=2000 w=800 g=-1.5 t=1,acompressor=threshold=-24dB:ratio=3.5:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'Edifier S3000Pro (Studio Punch)',
      label: '🔊 Edifier S3000Pro (Studio Punch)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.8,pan=stereo|FL=0.8*FL+0.4*FC+0.3*LFE|FR=0.8*FR+0.4*FC+0.3*LFE,anequalizer=c0 f=50 w=40 g=+3.0 t=1|c1 f=50 w=40 g=+3.0 t=1|c0 f=8000 w=2000 g=+2.0 t=1|c1 f=8000 w=2000 g=+2.0 t=1,acompressor=threshold=-16dB:ratio=1.8:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'KEF LS50 Wireless (Extreme Clarity)',
      label: '🔊 KEF LS50 Wireless (Extreme Clarity)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.8,pan=stereo|FL=0.85*FL+0.4*FC+0.3*LFE|FR=0.85*FR+0.4*FC+0.3*LFE,anequalizer=c0 f=60 w=50 g=+2.0 t=1|c1 f=60 w=50 g=+2.0 t=1|c0 f=2000 w=500 g=+1.5 t=1|c1 f=2000 w=500 g=+1.5 t=1|c0 f=6000 w=1500 g=+2.5 t=1|c1 f=6000 w=1500 g=+2.5 t=1,acompressor=threshold=-18dB:ratio=1.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Audioengine A5+ (Warm & Rich)',
      label: '🔊 Audioengine A5+ (Warm & Rich)',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31:p=0.8,pan=stereo|FL=0.8*FL+0.5*FC+0.4*LFE|FR=0.8*FR+0.5*FC+0.4*LFE,anequalizer=c0 f=80 w=60 g=+3.5 t=1|c1 f=80 w=60 g=+3.5 t=1|c0 f=300 w=200 g=+1.5 t=1|c1 f=300 w=200 g=+1.5 t=1|c0 f=8000 w=2000 g=-1.0 t=1|c1 f=8000 w=2000 g=-1.0 t=1,acompressor=threshold=-20dB:ratio=2.0:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'Yamaha HS8 (Studio Flat)',
      label: '🔊 Yamaha HS8 (Studio Flat)',
      filter: '#af-add=lavfi=[dynaudnorm=f=500:g=31:p=0.9,pan=stereo|FL=0.9*FL+0.3*FC+0.2*LFE|FR=0.9*FR+0.3*FC+0.2*LFE,anequalizer=c0 f=1000 w=500 g=+1.0 t=1|c1 f=1000 w=500 g=+1.0 t=1,acompressor=threshold=-14dB:ratio=1.2:makeup=0.5dB]',
    ),
    const FavoriteProfile(
      id: 'Creative Pebble V3 (Maximized)',
      label: '🔊 Creative Pebble V3 (Maximized)',
      filter: '#af-add=lavfi=[dynaudnorm=f=150:g=31:p=0.95,pan=stereo|FL=0.5*FL+0.7*FC+0.8*LFE|FR=0.5*FR+0.7*FC+0.8*LFE,anequalizer=c0 f=100 w=80 g=+6.0 t=1|c1 f=100 w=80 g=+6.0 t=1|c0 f=3000 w=1000 g=+2.5 t=1|c1 f=3000 w=1000 g=+2.5 t=1,acompressor=threshold=-30dB:ratio=5:attack=5:release=50:makeup=6dB,alimiter=limit=-1dB]',
    ),
    const FavoriteProfile(
      id: 'Standard 7.1 Home Theater',
      label: '🔊 Standard 7.1 Home Theater',
      filter: '#af-add=lavfi=[dynaudnorm=f=500:g=31,pan=7.1|FL=FL|FR=FR|FC=FC|LFE=LFE|BL=BL|BR=BR|SL=SL|SR=SR,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1,acompressor=threshold=-16dB:ratio=2:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'Bose Companion 20 (Stereo)',
      label: '🔊 Bose Companion 20 (Stereo)',
      filter: '#af-add=lavfi=[dynaudnorm=f=450:g=31,pan=stereo|FL=0.8*FL+0.5*FC+0.3*LFE|FR=0.8*FR+0.5*FC+0.3*LFE,extrastereo=0.15,anequalizer=c0 f=80 w=60 g=+2.0 t=1|c1 f=80 w=60 g=+2.0 t=1|c0 f=250 w=100 g=-1.5 t=1|c1 f=250 w=100 g=-1.5 t=1,acompressor=threshold=-20dB:ratio=2.2:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Razer Leviathan Soundbar',
      label: '🔊 Razer Leviathan Soundbar',
      filter: '#af-add=lavfi=[dynaudnorm=f=250:g=31:p=0.85,pan=stereo|FL=0.6*FL+0.4*FC+0.5*BL+0.3*LFE|FR=0.6*FR+0.4*FC+0.5*BR+0.3*LFE,extrastereo=0.4,anequalizer=c0 f=100 w=80 g=+2.5 t=1|c1 f=100 w=80 g=+2.5 t=1|c0 f=4000 w=1000 g=+1.5 t=1|c1 f=4000 w=1000 g=+1.5 t=1,acompressor=threshold=-22dB:ratio=4:makeup=3dB]',
    ),
    const FavoriteProfile(
      id: 'PreSonus Eris E3.5 (Tamed)',
      label: '🔊 PreSonus Eris E3.5 (Tamed)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31,pan=stereo|FL=0.85*FL+0.4*FC+0.3*LFE|FR=0.85*FR+0.4*FC+0.3*LFE,anequalizer=c0 f=100 w=80 g=-2.0 t=1|c1 f=100 w=80 g=-2.0 t=1|c0 f=8000 w=2000 g=+1.5 t=1|c1 f=8000 w=2000 g=+1.5 t=1,acompressor=threshold=-18dB:ratio=2.0:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Edifier R1280T (Clarity Boost)',
      label: '🔊 Edifier R1280T (Clarity Boost)',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31:p=0.8,pan=stereo|FL=0.8*FL+0.5*FC+0.3*LFE|FR=0.8*FR+0.5*FC+0.3*LFE,anequalizer=c0 f=200 w=150 g=-1.5 t=1|c1 f=200 w=150 g=-1.5 t=1|c0 f=4000 w=1000 g=+2.5 t=1|c1 f=4000 w=1000 g=+2.5 t=1|c0 f=8000 w=2000 g=+2.0 t=1|c1 f=8000 w=2000 g=+2.0 t=1,acompressor=threshold=-16dB:ratio=2.2:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'JBL 305P MkII (Fun V-Shape)',
      label: '🔊 JBL 305P MkII (Fun V-Shape)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.9,pan=stereo|FL=0.9*FL+0.3*FC+0.4*LFE|FR=0.9*FR+0.3*FC+0.4*LFE,anequalizer=c0 f=50 w=40 g=+3.5 t=1|c1 f=50 w=40 g=+3.5 t=1|c0 f=1000 w=500 g=-1.0 t=1|c1 f=1000 w=500 g=-1.0 t=1|c0 f=8000 w=2000 g=+2.0 t=1|c1 f=8000 w=2000 g=+2.0 t=1,acompressor=threshold=-18dB:ratio=1.5:makeup=1dB]',
    ),
  ],
  [
    const FavoriteProfile(
      id: 'Apple AirPods Pro',
      label: '🎧 Apple AirPods Pro',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+2.0 t=1|c1 f=60 w=50 g=+2.0 t=1|c0 f=3000 w=500 g=+1.5 t=1|c1 f=3000 w=500 g=+1.5 t=1,acompressor=threshold=-22dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Sony WH-1000XM Series',
      label: '🎧 Sony WH-1000XM Series',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=40 w=30 g=+4.0 t=1|c1 f=40 w=30 g=+4.0 t=1|c0 f=150 w=80 g=-2.0 t=1|c1 f=150 w=80 g=-2.0 t=1,acompressor=threshold=-18dB:ratio=3:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'Sennheiser HD600 Series',
      label: '🎧 Sennheiser HD600 Series',
      filter: '#af-add=lavfi=[dynaudnorm=f=500:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=30 w=20 g=+4.5 t=1|c1 f=30 w=20 g=+4.5 t=1|c0 f=4000 w=500 g=-1.5 t=1|c1 f=4000 w=500 g=-1.5 t=1,alimiter=limit=-0.5dB]',
    ),
    const FavoriteProfile(
      id: 'Beyerdynamic DT 990 Pro',
      label: '🎧 Beyerdynamic DT 990 Pro',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=70 w=50 g=+3.5 t=1|c1 f=70 w=50 g=+3.5 t=1|c0 f=8000 w=1500 g=+4.0 t=1|c1 f=8000 w=1500 g=+4.0 t=1,acompressor=threshold=-18dB:ratio=2.2:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'Audio-Technica ATH-M50x',
      label: '🎧 Audio-Technica ATH-M50x',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+2.5 t=1|c1 f=60 w=50 g=+2.5 t=1|c0 f=8000 w=2000 g=-2.0 t=1|c1 f=8000 w=2000 g=-2.0 t=1,acompressor=threshold=-18dB:ratio=2.5:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'Bose QuietComfort Series',
      label: '🎧 Bose QuietComfort Series',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=-1.5 t=1|c1 f=60 w=50 g=-1.5 t=1|c0 f=2500 w=800 g=+2.5 t=1|c1 f=2500 w=800 g=+2.5 t=1,acompressor=threshold=-20dB:ratio=2.2:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Samsung Galaxy Buds Pro',
      label: '🎧 Samsung Galaxy Buds Pro',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=100 w=80 g=-1.0 t=1|c1 f=100 w=80 g=-1.0 t=1|c0 f=4000 w=1000 g=+1.5 t=1|c1 f=4000 w=1000 g=+1.5 t=1,acompressor=threshold=-22dB:ratio=3:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'Apple AirPods',
      label: '🎧 Apple AirPods (Regular)',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+4.5 t=1|c1 f=60 w=50 g=+4.5 t=1|c0 f=6000 w=1200 g=-1.5 t=1|c1 f=6000 w=1200 g=-1.5 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Apple AirPods Max',
      label: '🎧 Apple AirPods Max',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=-2.0 t=1|c1 f=60 w=50 g=-2.0 t=1|c0 f=2500 w=600 g=+2.0 t=1|c1 f=2500 w=600 g=+2.0 t=1,acompressor=threshold=-18dB:ratio=2:makeup=1dB,alimiter=limit=-0.5dB]',
    ),
    const FavoriteProfile(
      id: 'Beats Studio3',
      label: '🎧 Beats Studio3',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=-4.5 t=1|c1 f=60 w=50 g=-4.5 t=1|c0 f=2500 w=600 g=+3.0 t=1|c1 f=2500 w=600 g=+3.0 t=1|c0 f=8000 w=1500 g=+1.5 t=1|c1 f=8000 w=1500 g=+1.5 t=1,acompressor=threshold=-18dB:ratio=2.5:makeup=2dB]',
    ),
    const FavoriteProfile(
      id: 'Anker Soundcore Life Q Series',
      label: '🎧 Anker Soundcore Life Q Series',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=70 w=50 g=-1.5 t=1|c1 f=70 w=50 g=-1.5 t=1|c0 f=2000 w=500 g=+2.5 t=1|c1 f=2000 w=500 g=+2.5 t=1|c0 f=7000 w=1500 g=+1.0 t=1|c1 f=7000 w=1500 g=+1.0 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Audio-Technica ATH-M40x',
      label: '🎧 Audio-Technica ATH-M40x',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+2.0 t=1|c1 f=60 w=50 g=+2.0 t=1|c0 f=8000 w=2000 g=+1.5 t=1|c1 f=8000 w=2000 g=+1.5 t=1,acompressor=threshold=-18dB:ratio=2.2:makeup=1dB]',
    ),
  ],
  [
    const FavoriteProfile(
      id: 'SteelSeries Arctis 7 / Nova Pro',
      label: '🎮 SteelSeries Arctis 7 / Nova Pro',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=70 w=50 g=+2.0 t=1|c1 f=70 w=50 g=+2.0 t=1|c0 f=500 w=200 g=-1.5 t=1|c1 f=500 w=200 g=-1.5 t=1|c0 f=3000 w=600 g=+2.5 t=1|c1 f=3000 w=600 g=+2.5 t=1|c0 f=9000 w=1500 g=+2.0 t=1|c1 f=9000 w=1500 g=+2.0 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Razer BlackShark V2',
      label: '🎮 Razer BlackShark V2',
      filter: '#af-add=lavfi=[dynaudnorm=f=300:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+2.5 t=1|c1 f=60 w=50 g=+2.5 t=1|c0 f=1000 w=300 g=+1.0 t=1|c1 f=1000 w=300 g=+1.0 t=1|c0 f=8000 w=1500 g=+2.5 t=1|c1 f=8000 w=1500 g=+2.5 t=1,acompressor=threshold=-20dB:ratio=2:makeup=1dB]',
    ),
    const FavoriteProfile(
      id: 'HyperX Cloud II / Alpha',
      label: '🎮 HyperX Cloud II / Alpha',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=80 w=60 g=-2.5 t=1|c1 f=80 w=60 g=-2.5 t=1|c0 f=2500 w=500 g=+2.5 t=1|c1 f=2500 w=500 g=+2.5 t=1|c0 f=6000 w=1500 g=+1.5 t=1|c1 f=6000 w=1500 g=+1.5 t=1,acompressor=threshold=-18dB:ratio=2.5:makeup=1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Corsair Virtuoso / HS Series',
      label: '🎮 Corsair Virtuoso / HS Series',
      filter: '#af-add=lavfi=[dynaudnorm=f=350:g=31,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=70 w=50 g=+1.5 t=1|c1 f=70 w=50 g=+1.5 t=1|c0 f=3000 w=600 g=+1.5 t=1|c1 f=3000 w=600 g=+1.5 t=1|c0 f=9000 w=1500 g=+1.0 t=1|c1 f=9000 w=1500 g=+1.0 t=1,acompressor=threshold=-18dB:ratio=2:makeup=1dB]',
    ),
  ],
  [
    const FavoriteProfile(
      id: 'Sonos Beam / Arc (Soundbar)',
      label: '📺 Sonos Beam / Arc (Soundbar)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.7,pan=stereo|FL=0.85*FL+0.5*FC+0.3*LFE|FR=0.85*FR+0.5*FC+0.3*LFE,anequalizer=c0 f=2000 w=500 g=+1.5 t=1|c1 f=2000 w=500 g=+1.5 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB,alimiter=limit=-1dB]',
    ),
    const FavoriteProfile(
      id: 'Samsung / LG Soundbar (Bundled)',
      label: '📺 Samsung / LG Soundbar (Bundled)',
      filter: '#af-add=lavfi=[dynaudnorm=f=400:g=31:p=0.8,pan=stereo|FL=0.8*FL+0.5*FC+0.2*LFE|FR=0.8*FR+0.5*FC+0.2*LFE,anequalizer=c0 f=80 w=60 g=-3.0 t=1|c1 f=80 w=60 g=-3.0 t=1|c0 f=2500 w=600 g=+3.0 t=1|c1 f=2500 w=600 g=+3.0 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=2dB,alimiter=limit=-1dB]',
    ),
    const FavoriteProfile(
      id: 'TV Built-in Speakers (Generic)',
      label: '📺 TV Built-in Speakers (Generic)',
      filter: '#af-add=lavfi=[dynaudnorm=f=200:g=31:p=0.85:m=6,pan=stereo|FL=0.6*FL+0.7*FC+0.2*LFE|FR=0.6*FR+0.7*FC+0.2*LFE,anequalizer=c0 f=40 w=30 g=-4.0 t=1|c1 f=40 w=30 g=-4.0 t=1|c0 f=150 w=80 g=+3.0 t=1|c1 f=150 w=80 g=+3.0 t=1|c0 f=2500 w=600 g=+3.5 t=1|c1 f=2500 w=600 g=+3.5 t=1|c0 f=6000 w=1500 g=-1.5 t=1|c1 f=6000 w=1500 g=-1.5 t=1,acompressor=threshold=-26dB:ratio=5:attack=3:release=60:makeup=5dB,alimiter=limit=-1.5dB]',
    ),
    const FavoriteProfile(
      id: 'Laptop / Monitor Speakers (Generic)',
      label: '📺 Laptop / Monitor Speakers (Generic)',
      filter: '#af-add=lavfi=[dynaudnorm=f=150:g=31:p=0.9:m=7,pan=stereo|FL=0.5*FL+0.8*FC+0.15*LFE|FR=0.5*FR+0.8*FC+0.15*LFE,anequalizer=c0 f=40 w=30 g=-6.0 t=1|c1 f=40 w=30 g=-6.0 t=1|c0 f=200 w=100 g=+3.5 t=1|c1 f=200 w=100 g=+3.5 t=1|c0 f=3000 w=700 g=+4.0 t=1|c1 f=3000 w=700 g=+4.0 t=1|c0 f=7000 w=1500 g=-2.0 t=1|c1 f=7000 w=1500 g=-2.0 t=1,acompressor=threshold=-28dB:ratio=6:attack=2:release=50:makeup=6dB,alimiter=limit=-1.5dB]',
    ),
  ],
  [
    const FavoriteProfile(
      id: 'Late Night Viewing',
      label: '🌛 Late Night Viewing',
      filter: '#af-add=lavfi=[dynaudnorm=f=150:g=31:p=0.9,pan=stereo|FL=0.5*FL+0.8*FC|FR=0.5*FR+0.8*FC,anequalizer=c0 f=80 w=60 g=-6.0 t=1|c1 f=80 w=60 g=-6.0 t=1|c0 f=2000 w=500 g=+3.0 t=1|c1 f=2000 w=500 g=+3.0 t=1,acompressor=threshold=-28dB:ratio=6.0:attack=2:release=50:makeup=8dB,alimiter=limit=-2dB]',
    ),
    const FavoriteProfile(
      id: 'Anime & Clear Vocals',
      label: '🎤 Anime & Clear Vocals',
      filter: '#af-add=lavfi=[dynaudnorm=f=250:g=31,pan=stereo|FL=0.6*FL+0.7*FC|FR=0.6*FR+0.7*FC,anequalizer=c0 f=100 w=50 g=-1.5 t=1|c1 f=100 w=50 g=-1.5 t=1|c0 f=1200 w=300 g=+2.5 t=1|c1 f=1200 w=300 g=+2.5 t=1|c0 f=3500 w=800 g=+2.0 t=1|c1 f=3500 w=800 g=+2.0 t=1,acompressor=threshold=-20dB:ratio=3.0:makeup=2.5dB]',
    ),
  ],
];

/// Flat view of every favorite regardless of menu grouping.
List<FavoriteProfile> get builtinFavorites =>
    builtinFavoriteGroups.expand((g) => g).toList();
