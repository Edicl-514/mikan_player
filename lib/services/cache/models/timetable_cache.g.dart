// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTimetableCacheCollection on Isar {
  IsarCollection<TimetableCache> get timetableCaches => this.collection();
}

const TimetableCacheSchema = CollectionSchema(
  name: r'TimetableCache',
  id: 2825108034192186074,
  properties: {
    r'animesJson': PropertySchema(
      id: 0,
      name: r'animesJson',
      type: IsarType.string,
    ),
    r'cachedAt': PropertySchema(
      id: 1,
      name: r'cachedAt',
      type: IsarType.long,
    ),
    r'expiresAt': PropertySchema(
      id: 2,
      name: r'expiresAt',
      type: IsarType.long,
    ),
    r'isExpired': PropertySchema(
      id: 3,
      name: r'isExpired',
      type: IsarType.bool,
    ),
    r'quarter': PropertySchema(
      id: 4,
      name: r'quarter',
      type: IsarType.string,
    )
  },
  estimateSize: _timetableCacheEstimateSize,
  serialize: _timetableCacheSerialize,
  deserialize: _timetableCacheDeserialize,
  deserializeProp: _timetableCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'quarter': IndexSchema(
      id: 5363798157439798837,
      name: r'quarter',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'quarter',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _timetableCacheGetId,
  getLinks: _timetableCacheGetLinks,
  attach: _timetableCacheAttach,
  version: '3.1.0+1',
);

int _timetableCacheEstimateSize(
  TimetableCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.animesJson.length * 3;
  bytesCount += 3 + object.quarter.length * 3;
  return bytesCount;
}

void _timetableCacheSerialize(
  TimetableCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.animesJson);
  writer.writeLong(offsets[1], object.cachedAt);
  writer.writeLong(offsets[2], object.expiresAt);
  writer.writeBool(offsets[3], object.isExpired);
  writer.writeString(offsets[4], object.quarter);
}

TimetableCache _timetableCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TimetableCache();
  object.animesJson = reader.readString(offsets[0]);
  object.cachedAt = reader.readLong(offsets[1]);
  object.expiresAt = reader.readLong(offsets[2]);
  object.id = id;
  object.quarter = reader.readString(offsets[4]);
  return object;
}

P _timetableCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _timetableCacheGetId(TimetableCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _timetableCacheGetLinks(TimetableCache object) {
  return [];
}

void _timetableCacheAttach(
    IsarCollection<dynamic> col, Id id, TimetableCache object) {
  object.id = id;
}

extension TimetableCacheByIndex on IsarCollection<TimetableCache> {
  Future<TimetableCache?> getByQuarter(String quarter) {
    return getByIndex(r'quarter', [quarter]);
  }

  TimetableCache? getByQuarterSync(String quarter) {
    return getByIndexSync(r'quarter', [quarter]);
  }

  Future<bool> deleteByQuarter(String quarter) {
    return deleteByIndex(r'quarter', [quarter]);
  }

  bool deleteByQuarterSync(String quarter) {
    return deleteByIndexSync(r'quarter', [quarter]);
  }

  Future<List<TimetableCache?>> getAllByQuarter(List<String> quarterValues) {
    final values = quarterValues.map((e) => [e]).toList();
    return getAllByIndex(r'quarter', values);
  }

  List<TimetableCache?> getAllByQuarterSync(List<String> quarterValues) {
    final values = quarterValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'quarter', values);
  }

  Future<int> deleteAllByQuarter(List<String> quarterValues) {
    final values = quarterValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'quarter', values);
  }

  int deleteAllByQuarterSync(List<String> quarterValues) {
    final values = quarterValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'quarter', values);
  }

  Future<Id> putByQuarter(TimetableCache object) {
    return putByIndex(r'quarter', object);
  }

  Id putByQuarterSync(TimetableCache object, {bool saveLinks = true}) {
    return putByIndexSync(r'quarter', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByQuarter(List<TimetableCache> objects) {
    return putAllByIndex(r'quarter', objects);
  }

  List<Id> putAllByQuarterSync(List<TimetableCache> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'quarter', objects, saveLinks: saveLinks);
  }
}

extension TimetableCacheQueryWhereSort
    on QueryBuilder<TimetableCache, TimetableCache, QWhere> {
  QueryBuilder<TimetableCache, TimetableCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TimetableCacheQueryWhere
    on QueryBuilder<TimetableCache, TimetableCache, QWhereClause> {
  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause>
      quarterEqualTo(String quarter) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'quarter',
        value: [quarter],
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterWhereClause>
      quarterNotEqualTo(String quarter) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'quarter',
              lower: [],
              upper: [quarter],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'quarter',
              lower: [quarter],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'quarter',
              lower: [quarter],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'quarter',
              lower: [],
              upper: [quarter],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TimetableCacheQueryFilter
    on QueryBuilder<TimetableCache, TimetableCache, QFilterCondition> {
  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'animesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'animesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'animesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'animesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      animesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'animesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      cachedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      cachedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      cachedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cachedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      cachedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cachedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      expiresAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      expiresAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      expiresAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expiresAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      expiresAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expiresAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      isExpiredEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isExpired',
        value: value,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quarter',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'quarter',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'quarter',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quarter',
        value: '',
      ));
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterFilterCondition>
      quarterIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'quarter',
        value: '',
      ));
    });
  }
}

extension TimetableCacheQueryObject
    on QueryBuilder<TimetableCache, TimetableCache, QFilterCondition> {}

extension TimetableCacheQueryLinks
    on QueryBuilder<TimetableCache, TimetableCache, QFilterCondition> {}

extension TimetableCacheQuerySortBy
    on QueryBuilder<TimetableCache, TimetableCache, QSortBy> {
  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByAnimesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animesJson', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByAnimesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animesJson', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> sortByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> sortByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> sortByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> sortByQuarter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quarter', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      sortByQuarterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quarter', Sort.desc);
    });
  }
}

extension TimetableCacheQuerySortThenBy
    on QueryBuilder<TimetableCache, TimetableCache, QSortThenBy> {
  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByAnimesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animesJson', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByAnimesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animesJson', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByCachedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cachedAt', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByExpiresAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expiresAt', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByIsExpiredDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isExpired', Sort.desc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy> thenByQuarter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quarter', Sort.asc);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QAfterSortBy>
      thenByQuarterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quarter', Sort.desc);
    });
  }
}

extension TimetableCacheQueryWhereDistinct
    on QueryBuilder<TimetableCache, TimetableCache, QDistinct> {
  QueryBuilder<TimetableCache, TimetableCache, QDistinct> distinctByAnimesJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'animesJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QDistinct> distinctByCachedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cachedAt');
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QDistinct>
      distinctByExpiresAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expiresAt');
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QDistinct>
      distinctByIsExpired() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isExpired');
    });
  }

  QueryBuilder<TimetableCache, TimetableCache, QDistinct> distinctByQuarter(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quarter', caseSensitive: caseSensitive);
    });
  }
}

extension TimetableCacheQueryProperty
    on QueryBuilder<TimetableCache, TimetableCache, QQueryProperty> {
  QueryBuilder<TimetableCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TimetableCache, String, QQueryOperations> animesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'animesJson');
    });
  }

  QueryBuilder<TimetableCache, int, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }

  QueryBuilder<TimetableCache, int, QQueryOperations> expiresAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expiresAt');
    });
  }

  QueryBuilder<TimetableCache, bool, QQueryOperations> isExpiredProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isExpired');
    });
  }

  QueryBuilder<TimetableCache, String, QQueryOperations> quarterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quarter');
    });
  }
}
