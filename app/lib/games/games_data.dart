// Static game content — Turkish, family-safe-ish for random chat.

/// Hangman words: 4–9 letters, no diacritic ambiguity, common Turkish nouns.
const List<String> kHangmanWords = [
  'kelebek', 'bulut', 'denizci', 'kahve', 'roket', 'kitap', 'müzik',
  'pizza', 'şehir', 'orman', 'şampiyon', 'futbol', 'tatil', 'kuzey',
  'köprü', 'sokak', 'gitar', 'piyano', 'sinema', 'tiyatro',
  'dağcı', 'bisiklet', 'kayak', 'yıldız', 'gezegen', 'galaksi',
  'kedi', 'köpek', 'aslan', 'kaplan', 'fil', 'penguen', 'kanguru',
  'çikolata', 'şeker', 'limon', 'karpuz', 'üzüm', 'kiraz', 'muz',
  'okyanus', 'ada', 'kanyon', 'çöl', 'kutup', 'volkan',
  'masal', 'roman', 'şiir', 'şarkı', 'dans', 'tango',
  'paris', 'tokyo', 'roma', 'istanbul', 'kapadokya',
];

/// Truth/Dare cards — Turkish, "Azar-style" tone (flirty-light, never explicit).
const List<String> kTruthCards = [
  'En son gizlice ne yedin?',
  'Hayatında en utanç verici an neydi?',
  'En son ne için ağladın?',
  'Bu uygulamada amacın ne?',
  'Hayalindeki ilk randevu nasıl olurdu?',
  'En kötü saç kesimin neydi?',
  'Sosyal medyada birini takipten çıkardın mı, kimi?',
  'En son söylediğin yalan neydi?',
  'İlk öpücüğünü hatırlıyor musun?',
  'En son birine âşık olduğunda nasıl anladın?',
  'Hiç bir ünlüyle eşleşmek ister miydin? Kim?',
  'Bana ilk izleniminden bahset.',
  'En garip rüyan neydi?',
  'Birine söyleyemediğin bir sırrın var mı?',
  'Bir günlük başkası olabilsen kim olurdun?',
  'En son ne için pişman oldun?',
  'En tuhaf hobibin?',
  'Hiç yanlış kişiye mesaj attın mı, ne oldu?',
  'Şu an aklından geçen ilk kişi kim?',
  'En son ne zaman beyaz yalan söyledin?',
  'Hayatında en cesur kararın neydi?',
  'İnsanların hakkında en çok yanıldığı şey ne?',
  'Bir süper gücün olsa hangisi olurdu?',
  'En sevdiğin emoji ne ve neden?',
  "Galeri'nin son fotoğrafı ne?",
];

const List<String> kDareCards = [
  'Karşıdaki kişiye 3 iltifat et.',
  '30 saniye gözünü kırpmadan karşıya bak.',
  'En kötü dans hareketini göster.',
  'Saçınla komik bir şekil yap.',
  'En sevdiğin şarkıdan bir bölümü mırıldan.',
  'Karşıdakine bir takma ad ver, sebebini de söyle.',
  'Bir hayvan taklidi yap, karşı tahmin etsin.',
  'En sevdiğin meme/akıma referans ver.',
  '30 saniye yalnız "bee bee" diye konuş.',
  'En komik suratını yap ve 5 saniye tut.',
  'Şu an üstünde olan en gereksiz eşyayı göster.',
  'Telefon galerinden son fotoyu kameraya göster (kişisel değilse).',
  '10 saniye boyunca alfabeyi tersten söylemeye çalış.',
  'Karşıdakine 1 dakika tek kelime cevap ver.',
  'Çocukken giydiğin en garip kıyafeti anlat.',
  'Sevdiğin bir filmden bir replik canlandır.',
  'Karşıdakine küçük bir hediye fikri sun (hayali).',
  'Tek ayak üstünde 15 saniye dur.',
  'En sevdiğin şarkıyı 5 saniyede özetle.',
  'Karşıdakine espri yap, gülerse kazanır.',
];

/// XOX win lines (rows, cols, diagonals over 0..8 grid).
const List<List<int>> kXoxWinLines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];
