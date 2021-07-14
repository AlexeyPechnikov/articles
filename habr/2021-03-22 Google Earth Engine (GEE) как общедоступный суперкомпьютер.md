# Google Earth Engine (GEE) как общедоступный суперкомпьютер

Опубликовано https://habr.com/ru/post/548292/

Сервис [Google Earth Engine](https://code.earthengine.google.com) предоставляет возможность бесплатно работать с огромными массивами пространственной информации. К примеру, в считанные минуты можно получить композитную мозаику (сборное изображение) по миллиону космоснимков. Считая, что каждая сцена (набор спектральных каналов) Landsat 8 занимает в сжатом виде 1 ГБ, при таком запросе обрабатывается объем информации порядка 1 ПБ. И все это доступно бесплатно, быстро, и в любое время. Но есть такое мнение (неправильное), что GEE на бесплатных аккаунтах позволяет обработать и экспортировать лишь небольшие наборы данных. На самом деле, такое впечатление вызвано лишь тем, что программировать на GEE можно начать, даже не читая документации сервиса, а вот извлечь много данных, все еще не читая документации, уже не получится. Далее мы рассмотрим три разных решения задачи векторизации растров и двумя разными способами напишем серверную GEE функцию для вычисления геохэша.

![](https://habrastorage.org/webt/bv/ec/r8/bvecr8h5hfan84vjfantmtwmsvw.jpeg)
<cut/>

## Введение

А вы любите работать на суперкомпьютерах (это университетские кластеры, к примеру)? Я - нет! Несмотря на всю их мощь, на практике зачастую полезность таких монстров совсем не очевидна. Вы можете меня упрекнуть в пристрастности (и это правда - для меня линукс дебиан, конечно, лучший, и убунта как его непутевый потомок тоже на что-то годится), но работать на околодесятилетней давности линуксе центос это совсем перебор (он и свежий-то всегда второй свежести, если глянуть на версии пакетов в нем). Впрочем, это еще цветочки. Чтобы зря не тратить драгоценные ресурсы суперкомпьютеров, на них обычно установлен коммерческий компилятор интел, притом очень мохнатого года (может быть старше самого центоса, который, видимо, когда-то уже обновляли). Но и это еще не беда, в конце концов. Планировщики ресурсов на таких системах часто вызывают оторопь, и есть с чего - при попытке запустить задание, скажем, на 128 ядрах, ничего не происходит, ни запуска задания, ни выдачи какой-либо ошибки от утилиты запуска. В процессе оказывается, что число доступных нам ядер равно двум (всегда удивляюсь, почему так мало по умолчанию дают ресурсов), увеличение квоты требует административной работы (зачастую, уже на этом этапе проще переключиться на какой-нибудь Amazon AWS). Но самое худшее начинается позже. С завидным постоянством бинарные модули того самого вышеупомянутого проприетарного компилятора оказываются установлены в домашней директории давно сгинувшего вместе со своей домашней директорией пользователя, а без них компилятор, естественно, ничего не компилирует. Конечно, другого компилятора в системе нет, ведь его код был бы не столь оптимален... Таким образом, ситуация проясняется - нам нужно найти подходящий центос, установить его где-то локально или в облаке, портировать на него нужный софт, сделать статические сборки (поскольку на целевой системе часть системных пакетов может быть заменена непонятно чем и откуда) и тогда, возможно, мы сможем все это запустить на доступных нам двух ядрах кластера (будет ли когда-нибудь доступно большее их количество - предугадать невозможно, по разным причинам). Я мог бы еще многое добавить, но вы уже понимаете, почему лично я не люблю суперкомпьютеры.

Теперь поговорим про другой суперкомпьютер - облачный и общедоступный сервис  [Google Earth Engine](https://code.earthengine.google.com). Все, что нам потребуется для начала работы - открыть ссылку в браузере и можно начинать писать код на javascript и скачивать данные (кстати, можно туда загрузить еще и свои данные, а еще можно использовать API сервиса для доступа из других сред разработки и языков). При этом сразу же доступно огромное количество данных и вычислительных ресурсов. На мой взгляд, все это вполне заслуживает того, чтобы почитать-таки документацию и научиться работать в сервисе достаточно эффективно. Впрочем, обработка и получение растров достаточно очевидны и так, тем более, что ко всем предоставляемым в сервисе наборам данных есть и примеры их визуализации, а для их скачивания на Google Drive (к примеру) в растровом формате (обычно, GeoTIFF) достаточно функции Export.image.toDrive. А вот работа с векторными данными, тем более, преобразование растров в вектор далеко не так очевидны и в интернет зачастую можно встретить жалобы, что не удается выгрузить несколько сот тысяч записей. Вот специально сейчас проверил - за 21 минуту мне удалось выгрузить 10 миллионов записей на Google Drive в формате GeoJSON, получив файл размером 2Гб. И это далеко не предел для бесплатного аккаунта (не говоря уж о том, что можно выгружать данные по частям).

## Преобразование растровых данных сервиса в точечные

Рассмотрим три подхода:

1. Простейший способ заключается в создании геометрии, включающей в себя требуемые точки, и получении для них атрибутов растра: 

```javascript
var points_with_attributes = Image.reduceRegion({
  reducer: ee.Reducer.toList(Image.bandNames().size()),
  geometry: points
})
```
Способ пригоден, в основном, при работе с векторными данными, которые мы хотим дополнить информацией с растров. Здесь мы априори знаем координаты всех точек и получаем для них атрибуты растра.

2. Способ поинтереснее предполагает преобразование в список всех пикселов растра, попадающих в указанную область. Извлечем сначала только атрибуты пикселов растра:

```javascript
var attributes = Image.reduceRegion({
  reducer: ee.Reducer.toList(Image.bandNames().size()),
  geometry: some_area
})
```

Метод рабочий, но с подвохом и ресурсоемкий. В чем же подвох? Дело в том, что в некоторых точках растра атрибутивные данные могут быть пропущены и такие точки исключаются в данном методе. То есть метод возвращает от нуля до полного набора точек, которые попадают в заданную область. И как только мы захотим получить и координаты возвращаемых точек, метод может перестать работать (если в данных есть пропуски, как отмечено выше). Посмотрим код примера:

```javascript
var latlon = ee.Image.pixelLonLat()
var points_with_attributes = image
  .addBands(latlon)
  .reduceRegion({
    reducer: ee.Reducer.toList(),
    geometry: some_area
  });
```

Функция ee.Image.pixelLonLat() создает растр с координатами каждой точки, который мы добавляем к рабочему растру. Этот код прекрасно работает, но только пока в растровых данных нет пропусков и длины списков координат и атрибутов совпадают (по возможности, все операции сервисом GEE выполняются параллельно и, в результате, список по каждому каналу формируется независимо). Кроме того, необходимо добавить перепроецирование данных, но эта операция ресурсозатратная и сильно ограничивает наши возможности обработки данных на бесплатном аккаунте:

```javascript
var latlon = ee.Image.pixelLonLat().reproject(image.projection())
var points_with_attributes = image
  .addBands(latlon)
  .reduceRegion({
    reducer: ee.Reducer.toList(),
    geometry: some_area
  });
```

К счастью, возможно разом решить обе проблемы:

```javascript
var latlon = ee.Image.pixelLonLat()
var points_with_attributes = image
  .addBands(latlon)
  .add(image.select(0).add(0))
  .reduceRegion({
    reducer: ee.Reducer.toList(),
    geometry: some_area
  });
```

Здесь мы принудительно выполняем бесполезное вычисление на данных (предполагается, что первый канал растра содержит числовые данные), чтобы унифицировать длину списков атрибутов и списков координат, а заодно и выполнить перепроецирование растра координат. В итоге, все координаты, для которых не определены атрибуты, будут удалены (это может во много раз уменьшить количество полученных точек), растр координат окажется спроецирован на растр атрибутов и данные будут корректно обработаны. Такой вот трюк, основанный на парадигме отложенных (ленивых) вычислений сервиса.

3. И, наконец, самый простой и быстрый способ, который позволит обработать много данных:

```javascript
var latlon = ee.Image.pixelLonLat()
var points_with_attributes = image
  .sample({
    region: some_area,
    geometries: true
  });
```

В коде выше флаг "geometries" указывает, нужны ли нам координаты точек или только их атрибуты.

## Создание собственных серверных функций

Обычно, кроме извлечения данных "как есть", мы еще хотим как-то их обработать. Это можно сделать локально, выгрузив данные, или непосредственно в сервисе GEE. Во втором случае, мы получаем огромные вычислительные ресурсы, но нужно написать специальный код для серверной обработки. Следует помнить, что в окне облачного редактора мы можем писать смесь клиентского и серверного кода (что часто приводит к различным ошибкам). Когда вы только начинаете писать серверные функции GEE, нужны рабочие примеры, но найти их сложно. Для примера напишем функцию вычисления [геохэша](https://en.wikipedia.org/wiki/Geohash), или хэша заметающей кривой (z-curve). Кстати, найти готовую реализацию такой функции мне не удалось, что еще раз подтверждает, как сложно начинающим найти примеры по серверным функциям GEE. Чем полезна такая функция? Кроме прочего, геохэш позволяет сделать пространственное объединение данных очень просто и без операций с геометрическими объектами - достаточно лишь сократить количество символов геохэша. Кодирование и декодирование геохэшей поддерживается в PostgreSQL/PostGIS, Google BigQuery и многих других системах. Итак, посмотрим простую реализацию функции в стиле С-кода:

```javascript
var geohash_accumulate = function(obj, list) {
  // define common variables
  var base32 = ee.String('0123456789bcdefghjkmnpqrstuvwxyz'); // (geohash-specific) Base32 map
  // get previous state variables
  var prev = ee.Dictionary(ee.List(list).get(-1));
  var lat = ee.Number(prev.get('lat',0));
  var lon = ee.Number(prev.get('lon',0));
  var idx = ee.Number(prev.get('idx',0));
  var bit = ee.Number(prev.get('bit',0));
  var evenBit = ee.Number(prev.get('evenBit',1));
  var geohash = ee.String(prev.get('geohash',''));
  var latMin = ee.Number(prev.get('latMin',-90));
  var latMax = ee.Number(prev.get('latMax',90));
  var lonMin = ee.Number(prev.get('lonMin',-180));
  var lonMax = ee.Number(prev.get('lonMax',180));
  
  // calculate substep bit step idx
  // bisect E-W longitude
  var lonMid = ee.Number(ee.Algorithms.If(evenBit.gt(0),                      lonMin.add(lonMax).divide(2), 0)      );
  idx =        ee.Number(ee.Algorithms.If(evenBit.gt(0).and(lon.gte(lonMid)), idx.multiply(2).add(1),       idx)    );
  lonMin =     ee.Number(ee.Algorithms.If(evenBit.gt(0).and(lon.gte(lonMid)), lonMid,                       lonMin) );
  idx =        ee.Number(ee.Algorithms.If(evenBit.gt(0).and(lon.lt(lonMid)),  idx.multiply(2),              idx)    );
  lonMax =     ee.Number(ee.Algorithms.If(evenBit.gt(0).and(lon.lt(lonMid)),  lonMid,                       lonMax) );
  // bisect N-S latitude
  var latMid=  ee.Number(ee.Algorithms.If(evenBit.eq(0),                      latMin.add(latMax).divide(2), 0)      );
  idx =        ee.Number(ee.Algorithms.If(evenBit.eq(0).and(lat.gte(latMid)), idx.multiply(2).add(1),       idx)    );
  latMin =     ee.Number(ee.Algorithms.If(evenBit.eq(0).and(lat.gte(latMid)), latMid,                       latMin) );
  idx =        ee.Number(ee.Algorithms.If(evenBit.eq(0).and(lat.lt(latMid)),  idx.multiply(2),              idx)    );
  latMax =     ee.Number(ee.Algorithms.If(evenBit.eq(0).and(lat.lt(latMid)),  latMid,                       latMax) );
  // check position
  evenBit = evenBit.not();
  bit =     bit.add(1);
  geohash = ee.String(ee.Algorithms.If(bit.eq(5), geohash.cat(base32.slice(idx,ee.Number(idx).add(1))), geohash));
  idx =     ee.Number(ee.Algorithms.If(bit.eq(5), ee.Number(0), idx));
  bit =     ee.Number(ee.Algorithms.If(bit.eq(5), ee.Number(0), bit));
  
  // return state
  var curr = prev
    .set('idx',     idx     )
    .set('bit',     bit    )
    .set('evenBit', evenBit)
    .set('geohash', geohash)
    .set('latMin',  latMin )
    .set('latMax',  latMax )
    .set('lonMin',  lonMin )
    .set('lonMax',  lonMax );
  return ee.List([curr]);
};
function geohash_encode(lat, lon, precision) {
  var init = ee.Dictionary({lat: lat, lon: lon})
  var state = ee.List.sequence(1,precision*5).iterate(geohash_accumulate, ee.List([init]))
  return ee.String(ee.Dictionary(ee.List(state).get(-1)).get('geohash'))
}
```

Сделаем также простую проверку полученных геохэшей

```javascript
// PostGIS check from https://postgis.net/docs/ST_GeoHash.html
print (ee.Algorithms.If(geohash_encode(48, -126, 20).compareTo('c0w3hf1s70w3hf1s70w3'),'Error','OK'));
// Google BigQuery check from https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_geohash
print (ee.Algorithms.If(geohash_encode(47.62, -122.35, 10).compareTo('c22yzugqw7'),'Error','OK'));
```

Вместо использования вложенных циклов в функции geohash_encode() мы создаем функцию geohash_accumulate() и вызываем ее 5 раз для вычисления каждого символа геохэша. С учетом того, что GEE лимитирует количество вызовов функций, это не слишком масштабируемое решение. Как можно улучшить функцию? Проще всего продублировать пятикратно участок кода под комментарием "calculate substep bit step idx" и вызывать полученную функцию geohash_accumulate() лишь единожды для каждого вычисляемого символа (при желании, можно также сократить количество передаваемых между вызовами переменных). А можно и переписать код внутренней функции в функциональном стиле. Я, в общем-то, и не собирался этого делать, но пока я писал текст статьи, мне стало интересно попробовать и вот что получилось:

```javascript
var geohash_accumulate = function(obj, list) {
  // define common variables
  var range4 = ee.List.sequence(0,4).map(function(val){return ee.Number(val).multiply(1/4)});
  var range8 = ee.List.sequence(0,8).map(function(val){return ee.Number(val).multiply(1/8)});

  // get previous state
  var prev = ee.Dictionary(ee.List(list).get(-1))
  var lat = ee.Number(prev.get('lat',0))
  var lon = ee.Number(prev.get('lon',0))
  var n = ee.Number(prev.get('n',0)).add(1)
  var geohash = ee.String(prev.get('geohash',''))
  var latMin = ee.Number(prev.get('latMin',-90))
  var latMax = ee.Number(prev.get('latMax',90))
  var lonMin = ee.Number(prev.get('lonMin',-180))
  var lonMax = ee.Number(prev.get('lonMax',180))

  // calculate step n
  var base32 = ee.String(ee.Algorithms.If(n.mod(2).eq(1), '028b139c46df57eghksujmtvnqwyprxz', '0145hjnp2367kmqr89destwxbcfguvyz'));
  var latRange = ee.List(ee.Number(ee.Algorithms.If(n.mod(2).eq(1), range4, range8)));
  latRange = latRange.map(function(item){return ee.Number(item).multiply(latMax.subtract(latMin)).add(latMin)});
  var lonRange = ee.List(ee.Number(ee.Algorithms.If(n.mod(2).eq(1), range8, range4)));
  lonRange = lonRange.map(function(item){return ee.Number(item).multiply(lonMax.subtract(lonMin)).add(lonMin)});
  var latIdx = latRange.indexOf(latRange.filter(ee.Filter.lte('item', lat)).get(-1));
  latIdx = ee.Number(ee.Algorithms.If(latIdx.gte(latRange.size().add(-1)), latIdx.add(-1), latIdx));
  var lonIdx = lonRange.indexOf(lonRange.filter(ee.Filter.lte('item', lon)).get(-1));
  lonIdx = ee.Number(ee.Algorithms.If(lonIdx.gte(lonRange.size().add(-1)), lonIdx.add(-1), lonIdx));
  var idx = lonIdx.multiply(latRange.size().add(-1)).add(latIdx);
  // reset bounds
  latMin = latRange.get(latIdx)
  latMax = latRange.get(latIdx.add(1))
  lonMin = lonRange.get(lonIdx)
  lonMax= lonRange.get(lonIdx.add(1))
  // define geohash symbol
  var geohash = geohash.cat(base32.slice(idx,ee.Number(idx).add(1)));

  // return state
  var curr = prev
    .set('n',       n       )
    .set('geohash', geohash )
    .set('latMin',  latMin  )
    .set('latMax',  latMax  )
    .set('lonMin',  lonMin  )
    .set('lonMax',  lonMax  );
  return ee.List([curr]);
};
function geohash_encode(lat, lon, precision) {
  var init = ee.Dictionary({lat: lat, lon: lon})
  var state = ee.List.sequence(1,precision).iterate(geohash_accumulate, ee.List([init]))
  return ee.String(ee.Dictionary(ee.List(state).get(-1)).get('geohash'))
}
```

Да, это та же самая функция, только уже в Javascript-стиле, и требует в пять раз меньше вызовов внутренней функции, что позволит нам обработать примерно впятеро раз больше данных на бесплатном аккаунте. 

## Заключение

Сегодня мы рассмотрели еще кусочек мозаики из мира пространственной обработки данных. Как обычно, я рассказал о том, что бесплатно доступно каждому и легко может быть повторено, поскольку весь код перед вами. Конечно, и этот код будет доступен на моем GitHub (смотрите репозиторий [GIS Snippets](https://github.com/mobigroup/gis-snippets/tree/master/) в поддиректории GEE). Сразу не выложил, поскольку там надо сначала порядок навести - оказывается, чего у меня только не накопилось за два десятилетия работы с пространственными данными и программирования вообще.