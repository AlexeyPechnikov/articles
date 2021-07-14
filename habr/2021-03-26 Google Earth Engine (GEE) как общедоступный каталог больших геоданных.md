# Google Earth Engine (GEE) как общедоступный каталог больших геоданных

Опубликовано https://habr.com/ru/post/549142/

В прошлой статье [Google Earth Engine (GEE) как общедоступный суперкомпьютер](https://habr.com/ru/post/548292/) речь шла про работу в облачном редакторе GEE, где для доступа достаточно лишь наличия Google почты. Если потребности ограничиваются разовыми задачами и  гигабайтами извлекаемых данных, то этого вполне достаточно. Но для автоматизации множества даже мелких задач облачный редактор не лучший способ работы и, тем более, когда требуется многократно получать растры суммарным размером в терабайты. В таких случаях потребуются другие инструменты и сегодня мы рассмотрим возможности доступа из консольных shell и Python скриптов и Python Jupyter notebook.

![](https://habrastorage.org/webt/2i/ss/st/2issstoggq8zvgsvhxxoqb_lsho.jpeg)
На скриншоте Python Jupyter ноутбук, где растр с данными о плотности населения за 2020 год из каталога [Earth Engine data Catalog: WorldPop Global Project Population Data](https://developers.google.com/earth-engine/datasets/catalog/WorldPop_GP_100m_pop) отображен на карте OpenStreetMap
<cut/>

## Введение

Как говорится, аппетит приходит во время еды. Вот и я, хотя давно и с удовольствием работаю с Google Earth Engine (GEE), только недавно столкнулся с задачами, требующими регулярного извлечения терабайт данных для их последующей обработки. К счастью, это вполне реально. Более того, на GEE все нужные данные представлены в одном месте и регулярно обновляются, что делает его оптимальным источником. Конечно, мне понятно, насколько мало специалистов работают с такими наборами пространственной информации, и уж точно они не ищут статьи на русском языке (потому, что их нет). С другой стороны, специалисты по машинному обучению (ML) часто жалуются на недостаток данных, так вот же вам настоящий Клондайк! Есть разные варианты, как реализовать машинное обучение на этих данных - можно средствами GEE, можно обратиться к функциям Compute Engine или делать все самому. Впрочем, это отдельная большая тема, так что мы ограничимся лишь получением данных.

## Облачные акаунты Google

Для работы нам понадобится подключение к облачным аккаунтам [Google Cloud SDK](https://developers.google.com/cloud/sdk/gcloud) и установленный консольный **google-cloud-sdk**. При наличии гугл почты у нас уже есть один (или несколько) персональных аккаунтов.  Просмотреть список доступных аккаунтов и переключаться между ними можно с помощью консольной команды:

```bash
$ gcloud auth list
Credentialed accounts:
 - youremail@gmail.com (active)
To set the active account, run
 $ gcloud config set account <account>
```

Здесь уже отображена подсказка для переключения между аккаунтами:

```bash
$ gcloud config set account <account>
```

После переключения нужно авторизоваться в аккаунте :

```bash
$ gcloud auth login
```

## Доступ к облачным хранилищам

Обычных почтовых аккаунтов достаточно для доступа к облачным хранилищам buckets и Google Drive, куда можно сохранять данные GEE из облачного редактора GEE. Заметим, что при доступе через API данные возможно сохранить сразу локально.

Cохранение данных GEE на buckets выполняется с помощью функций Export.table.toCloudStorage и Export.image.toCloudStorage и используется в случаях, когда планируется дальнейшая работа с файлами в облаке [Google Compute Engine](https://cloud.google.com/compute). Управлять этими файлами можно с помощью утилиты **gsutil**, например:

```bash
$ gsutil du -h gs://mycloudstorage
```

Эта команда покажет список файлов и их размеры в удобных человеку единицах (см. ключ -h). С помощью утилиты gsutil можно осуществлять различные файловые операции, ключи достаточно интуитивны (cp, rm,...), подробности смотрите в справке указанной утилиты.

Для сохранения из GEE на Google Drive доступны команды Export.table.toDrive и Export.image.toDrive, дальнейшее управление файлами доступно в веб-интерфейсе или с помощью дополнительных утилит и приложений. Преимущественно сохранение на  Google Drive используется для скачивания готовых файлов.

## Доступ к GEE через API

Для не интерактивной работы с Google Earth Engine (GEE) рекомендуется создать так называемый сервисный аккаунт вида my-service-account@...iam.gserviceaccount.com: [Create and register a service account to use Earth Engine](https://developers.google.com/earth-engine/guides/service_account). Для доступа к GEE требуется в свойствах созданного аккаунта зайти на вкладку KEYS и создать и скачать JSON файл его ключа, а также зарегистрировать аккаунт на странице [Register a new service account](https://signup.earthengine.google.com/#!/service_accounts). Теперь с этим ключом можно авторизоваться с помощью следующего Python кода:

```python
import ee
service_account = 'my-service-account@...iam.gserviceaccount.com'
credentials = ee.ServiceAccountCredentials(service_account, 'privatekey.json')
ee.Initialize(credentials)
```

вместо использования функции Python API ee.Authenticate() с интерактивной авторизацией каждого сеанса. Смотрите также консольную авторизацию

```bash
$ earthengine earthengine --ee_config
```

Аналогично, ключ сервисного аккаунта позволяет авторизоваться и при использовании Python GDAL:

```python
import os
from osgeo import gdal

os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "my-service-account.json"
```

Или консольных утилит GDAL:

```shell
export GOOGLE_APPLICATION_CREDENTIALS=my-service-account.json
```

## Извлечение растров GEE

Для получения растров мы будем говорить о методе API [Method: projects.assets.getPixels](https://developers.google.com/earth-engine/reference/rest/v1alpha/projects.assets/getPixels) Такой доступ обеспечивает высокую скорость передачи данных и позволяет копировать огромные объемы данных, но отдельными блоками размером не более 32MB. К счастью, проект GDAL уже предоставляет обертку для этого API, так что достаточно одного вызова нужной утилиты или функции для передачи всего растра целиком.

Возьмем практический пример для консольных утилит GDAL и на Python. Просмотрим набор данных [WorldPop/GP/100m/pop](https://developers.google.com/earth-engine/datasets/catalog/WorldPop_GP_100m_pop) и извлечем один из найденных растров за 2020 год. Растры в этом наборе варьируются в размере по порядку величины от мегабайт до гигабайт, для примера выберем один из небольших: 

```shell
export GOOGLE_APPLICATION_CREDENTIALS=my-service-account.json

# fetch collection
ogrinfo -ro -al "EEDA:" -oo COLLECTION=projects/earthengine-public/assets/WorldPop/GP/100m/pop -where "year=2020" 
# show one raster info
gdalinfo "EEDAI:projects/earthengine-public/assets/WorldPop/GP/100m/pop/ZWE_2020"
# fetch one raster to local drive
gdal_translate "EEDAI:projects/earthengine-public/assets/WorldPop/GP/100m/pop/ZWE_2020" ZWE_2020.tif
```

Аналогично на Python:

```python
import os
from osgeo import ogr, gdal

# define service account key
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "my-service-account.json"
# fetch collection
driver = ogr.GetDriverByName('EEDA')
ds = driver.Open('EEDA:projects/earthengine-public/assets/WorldPop/GP/100m/pop')
layer = ds.GetLayer()
# filter collection by attribute
layer.SetAttributeFilter('year=2020')
# select 1st raster
for feature in layer:
    name = feature.GetField("name")
    crs = feature.GetField("band_crs")
    print ('raster name and crs:',name, crs)
    break
# fetch 1st raster from the collection to array
ds = gdal.Open(f'EEDAI:{name}')
band = ds.GetRasterBand(1)
array = band.ReadAsArray()
print ('raster shape:', array.shape)
```

## Заключение

Выше мы рассмотрели достаточно «продвинутые» техники работы с Google Earth Engine. Если вы обращаетесь к GEE регулярно, намного удобнее использовать шелл скрипты и Python Jupyter ноутбуки и иметь возможность сохранять практически произвольные объемы данных локально без промежуточных облачных хранилищ и без ожидания выполнения очереди заданий экспорта, которое может затянуться. Отдельно отмечу, что вовсе не обязательно извлекать «сырые» данные - можно их предварительно обработать средствами GEE. За подробностями серверной обработки, работы с GDAL и отображения данных обратитесь к ссылкам ниже.

Мне было бы интересно получить обратную связь от читателей: стоит ли обращаться к более сложным темам или и это уже за гранью того, что интересует русскоязычную аудиторию? Знаю, что немало читателей здесь используют Google Transtale и подобные переводчики, возможно, стоит сразу писать на английском на LinkedIn, как я уже делаю с публикациями по геофизике.

## Ссылки

[EEDAI - Google Earth Engine Data API Image](https://gdal.org/drivers/raster/eedai.html)

[Raster API tutorial](https://gdal.org/tutorials/raster_api_tut.html)

[Vector Layers](https://pcjericks.github.io/py-gdalogr-cookbook/vector_layers.html#iterate-over-features)

[Using GDAL / OGR for Data Processing and Analysis](https://download.osgeo.org/gdal/presentations/OpenSource_Weds_Andre_CUGOS.pdf)

[Raster Layers](https://pcjericks.github.io/py-gdalogr-cookbook/raster_layers.html)

[Raster (gridded) dataset handling](https://hydro-informatics.github.io/geo-raster.html)

[FROM GEE TO NUMPY TO GEOTIFF](https://mygeoblog.com/2017/10/06/from-gee-to-numpy-to-geotiff/)

[How to load GeoJSON files into BigQuery GIS](https://medium.com/google-cloud/how-to-load-geojson-files-into-bigquery-gis-9dc009802fb4)