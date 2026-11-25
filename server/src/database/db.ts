import crypto from 'crypto';
import { CharacterRecord, CategoryInfo } from './schema';
import { DataImporter, ImportReport } from './importer';
import {
  RAW_CRICKET_DATA,
  RAW_NARUTO_DATA,
  RAW_ONE_PIECE_DATA,
  RAW_DRAGON_BALL_DATA,
  RAW_POKEMON_DATA,
  RAW_DEMON_SLAYER_DATA,
  RAW_JUJUTSU_KAISEN_DATA,
  RAW_CARTOONS_DATA,
  RAW_SUPERHEROES_DATA,
  RAW_AVENGERS_DATA,
  RAW_OTHER_ANIME_DATA,
  RAW_BLEACH_DATA,
  RAW_ATTACK_ON_TITAN_DATA,
  RAW_MY_HERO_ACADEMIA_DATA,
  RAW_FOOTBALL_DATA,
  RAW_BASKETBALL_DATA,
  RAW_TENNIS_DATA,
  RAW_WWE_DATA,
  RAW_BEN_10_DATA,
  RAW_DORAEMON_DATA,
  RAW_SHINCHAN_DATA,
  RAW_BATMAN_DATA,
  RAW_SUPERMAN_DATA,
  RAW_SPIDER_MAN_DATA,
  RAW_IRON_MAN_DATA,
  RAW_CAPTAIN_AMERICA_DATA,
  RAW_THOR_DATA,
  RAW_HULK_DATA,
  RAW_X_MEN_DATA,
  RAW_GUARDIANS_OF_THE_GALAXY_DATA,
  RAW_MARVEL_DATA,
} from './catalogs';

export interface CategorySummaryDTO {
  id: string;
  name: string;
  actualCount: number;
  targetCount: number;
  isEnough5: boolean;
  isEnough8: boolean;
  isEnough10: boolean;
  isEnough25: boolean;
  scoringMethod: string;
  provenance: string;
  parentCategoryId?: string;
}

export function fisherYatesShuffle<T>(array: T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    const temp = result[i];
    result[i] = result[j];
    result[j] = temp;
  }
  return result;
}

export class CharacterDatabase {
  private static instance: CharacterDatabase;
  private categoriesMap: Map<string, CategoryInfo> = new Map();
  private recordsMap: Map<string, CharacterRecord[]> = new Map();
  private reportsMap: Map<string, ImportReport> = new Map();
  private lastSequencesByCategory: Map<string, string[]> = new Map();

  private constructor() {
    this.initCategories();
    this.loadAndProcessAll();
  }

  public static getInstance(): CharacterDatabase {
    if (!CharacterDatabase.instance) {
      CharacterDatabase.instance = new CharacterDatabase();
    }
    return CharacterDatabase.instance;
  }

  private canonicalCategoryIds = [
    'cricket',
    'naruto',
    'one_piece',
    'dragon_ball',
    'pokemon',
    'demon_slayer',
    'jujutsu_kaisen',
    'classic_cartoons',
    'superheroes',
    'marvel_avengers',
    'other_anime',
  ];

  private initCategories(): void {
    const list: CategoryInfo[] = [
      // 1. ANIME
      {
        id: 'naruto',
        name: 'Naruto',
        parentCategoryId: 'anime',
        targetCount: 250,
        scoringMethod: 'Fictional Ninja Power Tier Rubric (Chakra levels, Kekkei Genkai, Jutsu mastery)',
        provenance: 'Official Naruto Databooks 1-4 & Canon Manga Ratings',
      },
      {
        id: 'one_piece',
        name: 'One Piece',
        parentCategoryId: 'anime',
        targetCount: 300,
        scoringMethod: 'Combat Power Rubric (Haki proficiency, Devil Fruit Awakening, Bounties)',
        provenance: 'One Piece Vivre Card Databooks & Canon Manga Ratings',
      },
      {
        id: 'demon_slayer',
        name: 'Demon Slayer',
        parentCategoryId: 'anime',
        targetCount: 150,
        scoringMethod: 'Combat Rank Rubric (Breathing Styles, Hashira/Upper Moon Tiering)',
        provenance: 'Demon Slayer Official Fanbooks 1-2 & Canon Manga Ratings',
      },
      {
        id: 'jujutsu_kaisen',
        name: 'Jujutsu Kaisen',
        parentCategoryId: 'anime',
        targetCount: 150,
        scoringMethod: 'Sorcerer Grade & Cursed Energy Output Rubric (Special Grade to Grade 4)',
        provenance: 'Jujutsu Kaisen Official Fanbook & Canon Manga Ratings',
      },
      {
        id: 'dragon_ball',
        name: 'Dragon Ball',
        parentCategoryId: 'anime',
        targetCount: 200,
        scoringMethod: 'Fictional Battle Power Rubric (Ki mastery, Divine forms, Ultra Instinct)',
        provenance: 'Daizenshuu Official Guides & Canon Anime/Manga Ratings',
      },
      {
        id: 'bleach',
        name: 'Bleach',
        parentCategoryId: 'anime',
        targetCount: 150,
        scoringMethod: 'Spiritual Pressure (Reiryoku) & Zanpakuto Release Power Rubric',
        provenance: 'Bleach Official Character Books & Canon Manga Ratings',
      },
      {
        id: 'attack_on_titan',
        name: 'Attack on Titan',
        parentCategoryId: 'anime',
        targetCount: 150,
        scoringMethod: 'Titan Shifter Combat & Survey Corps Battle Rating Rubric',
        provenance: 'Attack on Titan Guidebooks & Canon Manga Ratings',
      },
      {
        id: 'my_hero_academia',
        name: 'My Hero Academia',
        parentCategoryId: 'anime',
        targetCount: 150,
        scoringMethod: 'Quirk Power, Versatility & Pro Hero Chart Tiering Rubric',
        provenance: 'My Hero Academia Official Character Books & Canon Manga Ratings',
      },

      // 2. SPORTS
      {
        id: 'cricket',
        name: 'Cricket',
        parentCategoryId: 'sports',
        targetCount: 800,
        scoringMethod: 'ICC Career Performance Rating Scale (0-100 based on Batting/Bowling Averages & Strike Rates)',
        provenance: 'ICC Official International Stats & Wisden Records',
      },
      {
        id: 'football',
        name: 'Football',
        parentCategoryId: 'sports',
        targetCount: 200,
        scoringMethod: 'FIFA Career Legend Rating (Ballon d\'Or, Caps, Goals & Trophies)',
        provenance: 'FIFA Official Records, UEFA Champions League Stats & IFFHS Archive',
      },
      {
        id: 'basketball',
        name: 'Basketball',
        parentCategoryId: 'sports',
        targetCount: 200,
        scoringMethod: 'NBA Hall of Fame Rating Scale (PER, MVP Awards, Championships)',
        provenance: 'NBA Official Statistics & Naismith Memorial Basketball Hall of Fame',
      },
      {
        id: 'tennis',
        name: 'Tennis',
        parentCategoryId: 'sports',
        targetCount: 150,
        scoringMethod: 'ATP/WTA Grand Slam Performance & Career Peak Elo Rating Scale',
        provenance: 'ATP Tour, WTA Official Records & International Tennis Federation',
      },
      {
        id: 'wwe',
        name: 'WWE',
        parentCategoryId: 'sports',
        targetCount: 150,
        scoringMethod: 'Pro Wrestling World Championship Reigns & Iconic Match Rating',
        provenance: 'WWE Official Hall of Fame Archives & Title History Records',
      },

      // 3. CARTOONS
      {
        id: 'ben_10',
        name: 'Ben 10',
        parentCategoryId: 'cartoons',
        targetCount: 150,
        scoringMethod: 'Omnitrix Alien Power Rank & DNA Sample Rating Rubric',
        provenance: 'Man of Action Canon Continuity & Cartoon Network Official Fact Files',
      },
      {
        id: 'classic_cartoons',
        name: 'Tom and Jerry',
        parentCategoryId: 'cartoons',
        targetCount: 200,
        scoringMethod: 'Toon Force & Slapstick Durability Game Rating Rubric',
        provenance: 'Animation Studio Character Records & Game Stats',
      },
      {
        id: 'doraemon',
        name: 'Doraemon',
        parentCategoryId: 'cartoons',
        targetCount: 150,
        scoringMethod: '22nd Century Secret Gadget Capability & Character Influence Rubric',
        provenance: 'Fujiko F. Fujio Canon Manga Guides & Official Doraemon Encyclopedias',
      },
      {
        id: 'shinchan',
        name: 'Shinchan',
        parentCategoryId: 'cartoons',
        targetCount: 150,
        scoringMethod: 'Kasukabe Defense Force Spirit & Comic Mischief Power Rubric',
        provenance: 'Yoshito Usui Manga Canon & Shin-chan Official Character Encyclopedia',
      },
      {
        id: 'pokemon',
        name: 'Pokémon',
        parentCategoryId: 'cartoons',
        targetCount: 500,
        scoringMethod: 'Normalized Base Stat Total (BST / 720 * 100 Integer Rating)',
        provenance: 'Official Game Freak Pokémon Video Game Stat Databases',
      },

      // 4. SUPERHEROES
      {
        id: 'superheroes',
        name: 'DC',
        parentCategoryId: 'superheroes',
        targetCount: 200,
        scoringMethod: 'Comic Combat Power & Superpower Power Rank Rubric',
        provenance: 'DC Comics Official Character Encyclopedias & Canon Guides',
      },
      {
        id: 'batman',
        name: 'Batman',
        parentCategoryId: 'superheroes',
        targetCount: 150,
        scoringMethod: 'Bat-Family Tactical Intellect, Martial Arts & Prep Time Combat Rubric',
        provenance: 'DC Comics Batman Canon Files & Gotham Rogues Gallery Archives',
      },
      {
        id: 'superman',
        name: 'Superman',
        parentCategoryId: 'superheroes',
        targetCount: 150,
        scoringMethod: 'Kryptonian Solar Absorption & Multiversal God-Tier Feat Rubric',
        provenance: 'DC Comics Superman Secret Files & Action Comics Encyclopedias',
      },
      {
        id: 'spider_man',
        name: 'Spider-Man',
        parentCategoryId: 'superheroes',
        targetCount: 150,
        scoringMethod: 'Spider-Verse Proportional Arachnid Strength & Spider-Sense Rubric',
        provenance: 'Marvel Comics Spider-Man Canon Encyclopedias & Web-Head Dossiers',
      },
      {
        id: 'marvel_avengers',
        name: 'Avengers',
        parentCategoryId: 'superheroes',
        targetCount: 200,
        scoringMethod: 'Marvel Power Grid Rubric (Intelligence, Strength, Speed, Durability, Energy, Combat)',
        provenance: 'Official Handbook of Marvel Universe & Canon Comic Ratings',
      },

      // 5. MARVEL
      {
        id: 'marvel',
        name: 'Marvel',
        parentCategoryId: 'marvel',
        targetCount: 200,
        scoringMethod: 'Marvel Comics Canon Power Grid Rubric (Intelligence, Strength, Speed, Durability, Energy, Combat)',
        provenance: 'Official Handbook of the Marvel Universe & Marvel Comics Canon Ratings',
      },
      {
        id: 'iron_man',
        name: 'Iron Man',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Stark Technology Armor Tier & Arc Reactor Output Rating Rubric',
        provenance: 'Marvel Comics Iron Man Armor Manuals & Canon Tech Archives',
      },
      {
        id: 'captain_america',
        name: 'Captain America',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Super Soldier Serum Peak Human Potential & Vibranium Mastery Rubric',
        provenance: 'Marvel Comics Captain America Dossiers & S.H.I.E.L.D. Character Files',
      },
      {
        id: 'thor',
        name: 'Thor',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Asgardian All-Father Divine God-Force & Mjolnir Weather Control Rubric',
        provenance: 'Marvel Comics Thor Encyclopedias & Asgardian Realm Canon Lore',
      },
      {
        id: 'hulk',
        name: 'Hulk',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Gamma Radiation Rage Scaling & Limitless Physical Strength Rubric',
        provenance: 'Marvel Comics Incredible Hulk Encyclopedias & Gamma Mutation Files',
      },
      {
        id: 'x_men',
        name: 'X-Men',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Mutant Classification Tier (Omega Level to Alpha Level Power Rubric)',
        provenance: 'Marvel Comics X-Men Cerebro Records & Krakoan Era Canon Archives',
      },
      {
        id: 'guardians_of_the_galaxy',
        name: 'Guardians of the Galaxy',
        parentCategoryId: 'marvel',
        targetCount: 150,
        scoringMethod: 'Cosmic Marvel Spacefaring Combat & Artifact Mastery Rubric',
        provenance: 'Marvel Comics Cosmic Lore & Guardians of the Galaxy Dossiers',
      },

      // 6. OTHER
      {
        id: 'other_anime',
        name: 'Other Anime',
        parentCategoryId: 'other',
        targetCount: 200,
        scoringMethod: 'Cross-Anime Power Rating Scale (Normalized 0-100)',
        provenance: 'Official Anime Databooks & Canon Source Ratings',
      },
    ];

    list.forEach((c) => this.categoriesMap.set(c.id, c));
  }

  private loadAndProcessAll(): void {
    // 11 Original canonical datasets
    this.importCategoryData('cricket', RAW_CRICKET_DATA);
    this.importCategoryData('naruto', RAW_NARUTO_DATA);
    this.importCategoryData('one_piece', RAW_ONE_PIECE_DATA);
    this.importCategoryData('dragon_ball', RAW_DRAGON_BALL_DATA);
    this.importCategoryData('pokemon', RAW_POKEMON_DATA);
    this.importCategoryData('demon_slayer', RAW_DEMON_SLAYER_DATA);
    this.importCategoryData('jujutsu_kaisen', RAW_JUJUTSU_KAISEN_DATA);
    this.importCategoryData('classic_cartoons', RAW_CARTOONS_DATA);
    this.importCategoryData('superheroes', RAW_SUPERHEROES_DATA);
    this.importCategoryData('marvel_avengers', RAW_AVENGERS_DATA);
    this.importCategoryData('other_anime', RAW_OTHER_ANIME_DATA);

    // 19 New topic datasets
    this.importCategoryData('bleach', RAW_BLEACH_DATA);
    this.importCategoryData('attack_on_titan', RAW_ATTACK_ON_TITAN_DATA);
    this.importCategoryData('my_hero_academia', RAW_MY_HERO_ACADEMIA_DATA);
    this.importCategoryData('football', RAW_FOOTBALL_DATA);
    this.importCategoryData('basketball', RAW_BASKETBALL_DATA);
    this.importCategoryData('tennis', RAW_TENNIS_DATA);
    this.importCategoryData('wwe', RAW_WWE_DATA);
    this.importCategoryData('ben_10', RAW_BEN_10_DATA);
    this.importCategoryData('doraemon', RAW_DORAEMON_DATA);
    this.importCategoryData('shinchan', RAW_SHINCHAN_DATA);
    this.importCategoryData('batman', RAW_BATMAN_DATA);
    this.importCategoryData('superman', RAW_SUPERMAN_DATA);
    this.importCategoryData('spider_man', RAW_SPIDER_MAN_DATA);
    this.importCategoryData('iron_man', RAW_IRON_MAN_DATA);
    this.importCategoryData('captain_america', RAW_CAPTAIN_AMERICA_DATA);
    this.importCategoryData('thor', RAW_THOR_DATA);
    this.importCategoryData('hulk', RAW_HULK_DATA);
    this.importCategoryData('x_men', RAW_X_MEN_DATA);
    this.importCategoryData('guardians_of_the_galaxy', RAW_GUARDIANS_OF_THE_GALAXY_DATA);
    this.importCategoryData('marvel', RAW_MARVEL_DATA);
  }

  public importCategoryData(categoryId: string, rawData: any[]): ImportReport {
    const taggedData = rawData.map((item, idx) => ({
      ...item,
      id: `${categoryId}_${idx + 1}`,
      categoryId,
      scoringMethod: this.categoriesMap.get(categoryId)?.scoringMethod,
      provenance: item.provenance || this.categoriesMap.get(categoryId)?.provenance,
    }));

    const report = DataImporter.processAndValidate(taggedData);
    this.reportsMap.set(categoryId, report);
    this.recordsMap.set(categoryId, report.validRecords);

    console.log(
      `[Database Import] ${categoryId}: ${report.validCount} valid records loaded (${report.duplicateCount} duplicates, ${report.invalidCount} invalid)`
    );

    return report;
  }

  /**
   * Returns the canonical 11 categories by default for backward compatibility with Step 5 tests,
   * or all categories/topics when includeAllTopics is true.
   */
  public getCategorySummaryList(includeAllTopics: boolean = false): CategorySummaryDTO[] {
    const result: CategorySummaryDTO[] = [];
    const targetIds = includeAllTopics ? Array.from(this.categoriesMap.keys()) : this.canonicalCategoryIds;

    targetIds.forEach((id) => {
      const info = this.categoriesMap.get(id);
      if (!info) return;
      const validRecords = this.recordsMap.get(id) || [];
      const actualCount = validRecords.length;
      result.push({
        id: info.id,
        name: info.name,
        actualCount,
        targetCount: info.targetCount,
        isEnough5: actualCount >= 5,
        isEnough8: actualCount >= 8,
        isEnough10: actualCount >= 10,
        isEnough25: actualCount >= 25,
        scoringMethod: info.scoringMethod,
        provenance: info.provenance,
        parentCategoryId: info.parentCategoryId,
      });
    });
    return result;
  }

  /**
   * Returns all 30 catalog topics with their parent category assignments for 2-level UI selection.
   */
  public getAllTopicSummaryList(): CategorySummaryDTO[] {
    return this.getCategorySummaryList(true);
  }

  public static normalizeCategoryId(categoryId?: string): string {
    if (!categoryId) return 'cricket';
    let clean = categoryId.trim().toLowerCase().replace(/[\s-]+/g, '_');
    if (clean === 'anime') clean = 'other_anime';
    return clean;
  }

  public getCategorySummary(categoryId: string): CategorySummaryDTO | undefined {
    const cleanId = CharacterDatabase.normalizeCategoryId(categoryId);
    const list = this.getCategorySummaryList(true);
    return list.find((c) => c.id === cleanId);
  }

  public getEligibleRecordsForCategory(categoryId: string): CharacterRecord[] {
    const cleanId = CharacterDatabase.normalizeCategoryId(categoryId);
    const directRecords = this.recordsMap.get(cleanId);
    if (directRecords && directRecords.length > 0) {
      return directRecords.filter((r) => r.isActive !== false);
    }

    // Check if categoryId is a parent category (e.g. anime, sports, cartoons, superheroes, marvel, other)
    const normalizedParent = categoryId.trim().toLowerCase().replace(/[\s-]+/g, '_');
    const matched: CharacterRecord[] = [];
    const seenIds = new Set<string>();

    this.categoriesMap.forEach((info, key) => {
      if (info.parentCategoryId === normalizedParent || key === normalizedParent) {
        const topicRecords = this.recordsMap.get(key) || [];
        for (const r of topicRecords) {
          if (r.isActive !== false && !seenIds.has(r.id)) {
            seenIds.add(r.id);
            matched.push(r);
          }
        }
      }
    });

    return matched;
  }

  public getCharacterRecords(categoryId: string, count: number): CharacterRecord[] {
    const eligible = this.getEligibleRecordsForCategory(categoryId);

    if (eligible.length < count) {
      const available = eligible.length;
      throw new Error(
        `Insufficient valid records in category "${categoryId}". Requested ${count}, but only ${available} valid records exist.`
      );
    }

    // Return unique items slice
    return eligible.slice(0, count);
  }

  /**
   * Server-Authoritative Match Randomization
   * 1. Selects an unbiased random subset from the eligible character pool.
   * 2. Randomizes the bidding appearance order of that selected subset.
   * Completely independent of points, rankings, ratings, prices, popularity, or alphabetical order.
   * Power points and hidden formulas remain strictly server-side for match scoring.
   * Each genuinely new match generates an independent random queue without artificial duplicate suppression.
   */
  public getShuffledCharacterRecords(
    categoryId: string,
    count: number,
    _previousSequenceIds?: string[]
  ): CharacterRecord[] {
    const eligible = this.getEligibleRecordsForCategory(categoryId);

    if (eligible.length === 0) {
      throw new Error(`No eligible records found in category "${categoryId}".`);
    }

    let selectedSubset: CharacterRecord[] = [];
    if (eligible.length >= count) {
      const poolShuffle = fisherYatesShuffle(eligible);
      selectedSubset = poolShuffle.slice(0, count);
    } else {
      let cycle = 1;
      while (selectedSubset.length < count) {
        const round = fisherYatesShuffle(eligible).map((r, i) => ({
          ...r,
          id: cycle === 1 ? r.id : `${r.id}_c${cycle}_${i}`,
        }));
        selectedSubset.push(...round);
        cycle++;
      }
      selectedSubset = selectedSubset.slice(0, count);
    }

    // Step 2: Randomize the bidding appearance order of the selected subset
    const randomizedQueue = fisherYatesShuffle(selectedSubset);

    // Track latest sequence for category telemetry
    const selectedIds = randomizedQueue.map((item) => item.id);
    const cleanId = CharacterDatabase.normalizeCategoryId(categoryId);
    this.lastSequencesByCategory.set(cleanId, selectedIds);

    return randomizedQueue;
  }

  /**
   * Retrieves all valid character records for a category (or across all categories)
   * Useful for character pack generation and catalogue browsing.
   */
  public getAllCategoryRecords(categoryId?: string): CharacterRecord[] {
    if (categoryId) {
      let cleanId = categoryId.toLowerCase();
      if (cleanId === 'anime') cleanId = 'other_anime';
      return this.recordsMap.get(cleanId) || [];
    }
    const all: CharacterRecord[] = [];
    this.recordsMap.forEach((records) => {
      all.push(...records);
    });
    return all;
  }

  public clearShuffleHistory(): void {
    this.lastSequencesByCategory.clear();
  }
}
