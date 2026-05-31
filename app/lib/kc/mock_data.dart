import 'package:flutter/material.dart';

class KCUser {
  final String id;
  final String name;
  final int age;
  final String city;
  final String country;     // ISO-2
  final String gender;      // 'k' | 'e'
  final Color c1;
  final Color c2;
  final bool verified;
  final String lang;

  const KCUser({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.country,
    required this.gender,
    required this.c1,
    required this.c2,
    required this.verified,
    required this.lang,
  });
}

const kcUsers = <KCUser>[
  KCUser(id: 'elif', name: 'Elif', age: 23, city: 'İstanbul',  country: 'TR', gender: 'k',
         c1: Color(0xFFFF6B9D), c2: Color(0xFFC44DFF), verified: true,  lang: 'Türkçe'),
  KCUser(id: 'mara', name: 'Mara', age: 25, city: 'Madrid',    country: 'ES', gender: 'k',
         c1: Color(0xFFFF9F45), c2: Color(0xFFFF4D6D), verified: true,  lang: 'İspanyolca'),
  KCUser(id: 'yuki', name: 'Yuki', age: 22, city: 'Osaka',     country: 'JP', gender: 'k',
         c1: Color(0xFF5EC8FF), c2: Color(0xFF7A5BFF), verified: false, lang: 'Japonca'),
  KCUser(id: 'leo',  name: 'Leo',  age: 27, city: 'São Paulo', country: 'BR', gender: 'e',
         c1: Color(0xFF2BE0A6), c2: Color(0xFF1F9DC9), verified: true,  lang: 'Portekizce'),
  KCUser(id: 'nora', name: 'Nora', age: 24, city: 'Berlin',    country: 'DE', gender: 'k',
         c1: Color(0xFFA78BFA), c2: Color(0xFF5B8DEF), verified: false, lang: 'Almanca'),
  KCUser(id: 'aria', name: 'Aria', age: 21, city: 'Milano',    country: 'IT', gender: 'k',
         c1: Color(0xFFFF7E5F), c2: Color(0xFFFEB47B), verified: true,  lang: 'İtalyanca'),
  KCUser(id: 'kai',  name: 'Kai',  age: 26, city: 'Seoul',     country: 'KR', gender: 'e',
         c1: Color(0xFF36D1DC), c2: Color(0xFF5B86E5), verified: false, lang: 'Korece'),
];

const kcMe = KCUser(
  id: 'me', name: 'Deniz', age: 24, city: 'İzmir', country: 'TR', gender: 'e',
  c1: Color(0xFFFF5E8A), c2: Color(0xFFB15BFF), verified: true, lang: 'Türkçe',
);

// Subtitle scripts per partner-country, with TR translation.
const kcSubs = <String, List<String>>{
  'es': ['¡Hola! ¿Cómo estás?', 'Me encanta tu acento 😄', '¿De qué parte eres?'],
  'jp': ['こんにちは！はじめまして', 'トルコに行ってみたいな', '今日はいい天気だね'],
  'br': ['Oi! Tudo bem com você?', 'Adoro conhecer gente nova', 'Que horas são aí?'],
  'de': ['Hallo! Wie geht es dir?', 'Schön, dich kennenzulernen', 'Was machst du gerade?'],
  'it': ['Ciao! Come stai?', 'Mi piace il tuo sorriso', 'Cosa fai nella vita?'],
};

const kcSubsTr = <String, List<String>>{
  'es': ['Merhaba! Nasılsın?', 'Aksanına bayıldım 😄', 'Nerelisin?'],
  'jp': ['Merhaba! Memnun oldum', 'Türkiye\'yi görmek isterdim', 'Bugün hava çok güzel'],
  'br': ['Selam! İyi misin?', 'Yeni insanlarla tanışmaya bayılırım', 'Orada saat kaç?'],
  'de': ['Merhaba! Nasılsın?', 'Tanıştığımıza sevindim', 'Şu an ne yapıyorsun?'],
  'it': ['Selam! Nasılsın?', 'Gülüşüne bayıldım', 'Ne iş yapıyorsun?'],
};

const kcLangMap = <String, String>{
  'ES': 'es', 'JP': 'jp', 'BR': 'br', 'DE': 'de', 'IT': 'it', 'KR': 'jp', 'TR': 'es',
};

class KCGift {
  final String id;
  final String name;
  final String glyph;
  final int cost;
  const KCGift(this.id, this.name, this.glyph, this.cost);
}

const kcGifts = <KCGift>[
  KCGift('rose',   'Gül',     '🌹',   9),
  KCGift('heart',  'Kalp',    '💖',  19),
  KCGift('star',   'Yıldız',  '⭐',  29),
  KCGift('crown',  'Taç',     '👑',  99),
  KCGift('rocket', 'Roket',   '🚀', 149),
  KCGift('ring',   'Yüzük',   '💍', 299),
];

class KCCoinPack {
  final String id;
  final int coins;
  final String price;
  final String? bonus;
  final bool popular;
  const KCCoinPack(this.id, this.coins, this.price, {this.bonus, this.popular = false});
}

const kcCoinPacks = <KCCoinPack>[
  KCCoinPack('p1', 100,  '₺29'),
  KCCoinPack('p2', 550,  '₺99',  bonus: '+50'),
  KCCoinPack('p3', 1200, '₺199', bonus: '+200', popular: true),
  KCCoinPack('p4', 3000, '₺449', bonus: '+750'),
];

class KCChatPreview {
  final String uid;
  final String last;
  final String time;
  final int unread;
  final bool online;
  const KCChatPreview({required this.uid, required this.last, required this.time,
    required this.unread, required this.online});
}

const kcChats = <KCChatPreview>[
  KCChatPreview(uid: 'elif', last: 'Yarın aynı saatte? 😄',       time: '14:32', unread: 2, online: true),
  KCChatPreview(uid: 'mara', last: 'Te mando una foto de Madrid', time: '13:05', unread: 0, online: true),
  KCChatPreview(uid: 'leo',  last: 'Sen: haha kesinlikle!',        time: 'Dün',  unread: 0, online: false),
  KCChatPreview(uid: 'nora', last: 'Danke! Bis bald 👋',           time: 'Dün',  unread: 0, online: false),
  KCChatPreview(uid: 'aria', last: 'Ci sentiamo presto',           time: 'Sal',  unread: 1, online: true),
];

KCUser? kcUserById(String id) {
  for (final u in kcUsers) {
    if (u.id == id) return u;
  }
  return null;
}

/// Convert ISO-2 country code to flag emoji (regional indicator pairs).
String kcFlag(String code) {
  if (code.length != 2) return '';
  final upper = code.toUpperCase();
  final a = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(a) + String.fromCharCode(b);
}
