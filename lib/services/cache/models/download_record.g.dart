// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDownloadRecordCollection on Isar {
  IsarCollection<DownloadRecord> get downloadRecords => this.collection();
}

const DownloadRecordSchema = CollectionSchema(
  name: r'DownloadRecord',
  id: 5559596597395806655,
  properties: {
    r'animeName': PropertySchema(
      id: 0,
      name: r'animeName',
      type: IsarType.string,
    ),
    r'bangumiId': PropertySchema(
      id: 1,
      name: r'bangumiId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 2,
      name: r'createdAt',
      type: IsarType.long,
    ),
    r'downloaded': PropertySchema(
      id: 3,
      name: r'downloaded',
      type: IsarType.long,
    ),
    r'episodeNumber': PropertySchema(
      id: 4,
      name: r'episodeNumber',
      type: IsarType.long,
    ),
    r'filePath': PropertySchema(
      id: 5,
      name: r'filePath',
      type: IsarType.string,
    ),
    r'infoHash': PropertySchema(
      id: 6,
      name: r'infoHash',
      type: IsarType.string,
    ),
    r'magnet': PropertySchema(
      id: 7,
      name: r'magnet',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 8,
      name: r'name',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 9,
      name: r'status',
      type: IsarType.long,
    ),
    r'totalSize': PropertySchema(
      id: 10,
      name: r'totalSize',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 11,
      name: r'updatedAt',
      type: IsarType.long,
    )
  },
  estimateSize: _downloadRecordEstimateSize,
  serialize: _downloadRecordSerialize,
  deserialize: _downloadRecordDeserialize,
  deserializeProp: _downloadRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'infoHash': IndexSchema(
      id: -7504615971745441428,
      name: r'infoHash',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'infoHash',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _downloadRecordGetId,
  getLinks: _downloadRecordGetLinks,
  attach: _downloadRecordAttach,
  version: '3.1.0+1',
);

int _downloadRecordEstimateSize(
  DownloadRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.animeName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.bangumiId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.filePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.infoHash.length * 3;
  bytesCount += 3 + object.magnet.length * 3;
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _downloadRecordSerialize(
  DownloadRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.animeName);
  writer.writeString(offsets[1], object.bangumiId);
  writer.writeLong(offsets[2], object.createdAt);
  writer.writeLong(offsets[3], object.downloaded);
  writer.writeLong(offsets[4], object.episodeNumber);
  writer.writeString(offsets[5], object.filePath);
  writer.writeString(offsets[6], object.infoHash);
  writer.writeString(offsets[7], object.magnet);
  writer.writeString(offsets[8], object.name);
  writer.writeLong(offsets[9], object.status);
  writer.writeLong(offsets[10], object.totalSize);
  writer.writeLong(offsets[11], object.updatedAt);
}

DownloadRecord _downloadRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DownloadRecord();
  object.animeName = reader.readStringOrNull(offsets[0]);
  object.bangumiId = reader.readStringOrNull(offsets[1]);
  object.createdAt = reader.readLong(offsets[2]);
  object.downloaded = reader.readLong(offsets[3]);
  object.episodeNumber = reader.readLongOrNull(offsets[4]);
  object.filePath = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.infoHash = reader.readString(offsets[6]);
  object.magnet = reader.readString(offsets[7]);
  object.name = reader.readStringOrNull(offsets[8]);
  object.status = reader.readLong(offsets[9]);
  object.totalSize = reader.readLong(offsets[10]);
  object.updatedAt = reader.readLong(offsets[11]);
  return object;
}

P _downloadRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _downloadRecordGetId(DownloadRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _downloadRecordGetLinks(DownloadRecord object) {
  return [];
}

void _downloadRecordAttach(
    IsarCollection<dynamic> col, Id id, DownloadRecord object) {
  object.id = id;
}

extension DownloadRecordByIndex on IsarCollection<DownloadRecord> {
  Future<DownloadRecord?> getByInfoHash(String infoHash) {
    return getByIndex(r'infoHash', [infoHash]);
  }

  DownloadRecord? getByInfoHashSync(String infoHash) {
    return getByIndexSync(r'infoHash', [infoHash]);
  }

  Future<bool> deleteByInfoHash(String infoHash) {
    return deleteByIndex(r'infoHash', [infoHash]);
  }

  bool deleteByInfoHashSync(String infoHash) {
    return deleteByIndexSync(r'infoHash', [infoHash]);
  }

  Future<List<DownloadRecord?>> getAllByInfoHash(List<String> infoHashValues) {
    final values = infoHashValues.map((e) => [e]).toList();
    return getAllByIndex(r'infoHash', values);
  }

  List<DownloadRecord?> getAllByInfoHashSync(List<String> infoHashValues) {
    final values = infoHashValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'infoHash', values);
  }

  Future<int> deleteAllByInfoHash(List<String> infoHashValues) {
    final values = infoHashValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'infoHash', values);
  }

  int deleteAllByInfoHashSync(List<String> infoHashValues) {
    final values = infoHashValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'infoHash', values);
  }

  Future<Id> putByInfoHash(DownloadRecord object) {
    return putByIndex(r'infoHash', object);
  }

  Id putByInfoHashSync(DownloadRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'infoHash', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByInfoHash(List<DownloadRecord> objects) {
    return putAllByIndex(r'infoHash', objects);
  }

  List<Id> putAllByInfoHashSync(List<DownloadRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'infoHash', objects, saveLinks: saveLinks);
  }
}

extension DownloadRecordQueryWhereSort
    on QueryBuilder<DownloadRecord, DownloadRecord, QWhere> {
  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DownloadRecordQueryWhere
    on QueryBuilder<DownloadRecord, DownloadRecord, QWhereClause> {
  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause> idBetween(
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

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause>
      infoHashEqualTo(String infoHash) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'infoHash',
        value: [infoHash],
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterWhereClause>
      infoHashNotEqualTo(String infoHash) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'infoHash',
              lower: [],
              upper: [infoHash],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'infoHash',
              lower: [infoHash],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'infoHash',
              lower: [infoHash],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'infoHash',
              lower: [],
              upper: [infoHash],
              includeUpper: false,
            ));
      }
    });
  }
}

extension DownloadRecordQueryFilter
    on QueryBuilder<DownloadRecord, DownloadRecord, QFilterCondition> {
  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'animeName',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'animeName',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'animeName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'animeName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'animeName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'animeName',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      animeNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'animeName',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'bangumiId',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'bangumiId',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bangumiId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'bangumiId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'bangumiId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bangumiId',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      bangumiIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'bangumiId',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      createdAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      createdAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      createdAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      createdAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      downloadedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'downloaded',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      downloadedGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'downloaded',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      downloadedLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'downloaded',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      downloadedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'downloaded',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'episodeNumber',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'episodeNumber',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'episodeNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'episodeNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'episodeNumber',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      episodeNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'episodeNumber',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'filePath',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'filePath',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'filePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'filePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filePath',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      filePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'filePath',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
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

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
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

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'infoHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'infoHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'infoHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'infoHash',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      infoHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'infoHash',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'magnet',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'magnet',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'magnet',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'magnet',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      magnetIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'magnet',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      statusEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      statusGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      statusLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      statusBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      totalSizeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalSize',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      totalSizeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalSize',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      totalSizeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalSize',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      totalSizeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      updatedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      updatedAtGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      updatedAtLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterFilterCondition>
      updatedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DownloadRecordQueryObject
    on QueryBuilder<DownloadRecord, DownloadRecord, QFilterCondition> {}

extension DownloadRecordQueryLinks
    on QueryBuilder<DownloadRecord, DownloadRecord, QFilterCondition> {}

extension DownloadRecordQuerySortBy
    on QueryBuilder<DownloadRecord, DownloadRecord, QSortBy> {
  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByAnimeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animeName', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByAnimeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animeName', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloaded', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByDownloadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloaded', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByEpisodeNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'episodeNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByEpisodeNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'episodeNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByInfoHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'infoHash', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByInfoHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'infoHash', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByMagnet() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'magnet', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByMagnetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'magnet', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByTotalSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSize', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByTotalSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSize', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DownloadRecordQuerySortThenBy
    on QueryBuilder<DownloadRecord, DownloadRecord, QSortThenBy> {
  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByAnimeName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animeName', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByAnimeNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'animeName', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByBangumiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByBangumiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bangumiId', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloaded', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByDownloadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'downloaded', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByEpisodeNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'episodeNumber', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByEpisodeNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'episodeNumber', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByInfoHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'infoHash', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByInfoHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'infoHash', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByMagnet() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'magnet', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByMagnetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'magnet', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByTotalSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSize', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByTotalSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSize', Sort.desc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension DownloadRecordQueryWhereDistinct
    on QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> {
  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByAnimeName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'animeName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByBangumiId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bangumiId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct>
      distinctByDownloaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'downloaded');
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct>
      distinctByEpisodeNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'episodeNumber');
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByFilePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByInfoHash(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'infoHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByMagnet(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'magnet', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct> distinctByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status');
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct>
      distinctByTotalSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalSize');
    });
  }

  QueryBuilder<DownloadRecord, DownloadRecord, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension DownloadRecordQueryProperty
    on QueryBuilder<DownloadRecord, DownloadRecord, QQueryProperty> {
  QueryBuilder<DownloadRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DownloadRecord, String?, QQueryOperations> animeNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'animeName');
    });
  }

  QueryBuilder<DownloadRecord, String?, QQueryOperations> bangumiIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bangumiId');
    });
  }

  QueryBuilder<DownloadRecord, int, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<DownloadRecord, int, QQueryOperations> downloadedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'downloaded');
    });
  }

  QueryBuilder<DownloadRecord, int?, QQueryOperations> episodeNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'episodeNumber');
    });
  }

  QueryBuilder<DownloadRecord, String?, QQueryOperations> filePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filePath');
    });
  }

  QueryBuilder<DownloadRecord, String, QQueryOperations> infoHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'infoHash');
    });
  }

  QueryBuilder<DownloadRecord, String, QQueryOperations> magnetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'magnet');
    });
  }

  QueryBuilder<DownloadRecord, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<DownloadRecord, int, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<DownloadRecord, int, QQueryOperations> totalSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalSize');
    });
  }

  QueryBuilder<DownloadRecord, int, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
