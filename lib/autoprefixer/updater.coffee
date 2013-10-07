coffee = require('coffee-script')
https  = require('https')
fs     = require('fs')

module.exports =

  # Can I Use browser names to internal
  browsers:
    firefox: 'ff'
    chrome:  'chrome'
    safari:  'safari'
    ios_saf: 'ios'
    opera:   'opera'
    ie:      'ie'
    bb:      'bb'
    android: 'android'

  # Run all updater scrips
  run: ->
    updaters = __dirname + '/../../updaters/'
    for i in fs.readdirSync(updaters).sort()
      continue unless i.match(/\.(coffee|js)$/)
      require(updaters + i).apply(@)

  # Count of loading HTTP requests
  requests: 0

  # Callbacks from done() method
  doneCallbacks: []

  # Callbacks from request() method
  requestCallbacks: []

  # Execute `callback`, when all `caniuse` request will be finished
  done: (callback) ->
    @doneCallbacks ||= []
    @doneCallbacks.push(callback)

  # Execute `callback`, when HTTP request will be finished
  request: (callback) ->
    @requestCallbacks ||= []
    @requestCallbacks.push(callback)

  # Load file from GitHub RAWs
  github: (path, callback) ->
    @requests += 1
    https.get "https://raw.github.com/#{path}", (res) =>
      data = ''
      res.on 'data', (chunk) -> data += chunk
      res.on 'end', =>
        callback(JSON.parse(data))

        @requests -= 1
        func() for func in @requestCallbacks
        if @requests == 0
          func() for func in @doneCallbacks.reverse()

  # Correct sort by float versions
  sort: (browsers) ->
    browsers.sort (a, b) ->
      a = a.split(' ')
      b = b.split(' ')
      if a[0] > b[0]
        1
      else if a[0] < b[0]
        -1
      else
        parseFloat(a[1]) - parseFloat(b[1])

  # Parse browsers list in feature file
  parse: (data) ->
    need = []
    for browser, versions of data.stats
      for interval, support of versions
        for version in interval.split('-')
          if @browsers[browser] and support.match(/\sx($|\s)/)
            version = version.replace(/\.0$/, '')
            need.push(@browsers[browser] + ' ' + version)
    @sort(need)

  # Can I Use shortcut to request files in features/ dir.
  feature: (file, callback) ->
    url = "Fyrd/caniuse/master/features-json/#{file}.json"
    @github url, (data) => callback @parse(data)

  # Get Can I Use features from another user fork
  fork: (fork, file, callback) ->
    [user, branch] = fork.split('/')
    branch ||= 'master'
    url = "#{user}/caniuse/#{branch}/features-json/#{file}.json"
    @github url, (data) => callback @parse(data)

  # Call callback with list of all browsers
  all: (callback) ->
    browsers = require('../../data/browsers')
    list = []
    for name, data of browsers
      for version in data.versions
        list.push(name + ' ' + version)
    callback(@sort list)

  # Change browser array
  map: (browsers, callback) ->
    for browser in browsers
      [name, version] = browser.split(' ')
      version = parseFloat(version)

      callback(browser, name, version)

  # Return string of object. Like `JSON.stringify`, but output CoffeeScript.
  stringify: (obj, indent = '') ->
    if obj instanceof Array
      local = indent + '  '
      "[\n#{local}" +
        obj.map( (i) => @stringify(i, local) ).join("\n#{local}") +
      "\n#{indent}]"

    else if typeof(obj) == 'object'
      local = indent + '  '

      processed = []
      for key, value of obj
        key = "\"#{key}\"" if key.match(/'|-|@|:/)
        value = @stringify(value, local)
        value = ' ' + value unless value[0] == "\n"
        processed.push(key + ':' + value)

      "\n" + local + processed.join("\n#{local}") + "\n"

    else
      JSON.stringify(obj)

  # List of files changed by save() method
  changed: []

  # Save autogenerated `name` with warning comment and node.js exports.
  save: (name, json) ->
    sorted = {}
    sorted[key] = json[key] for key in Object.keys(json).sort()

    file     = __dirname + "/../../data/#{name}"
    content  = "# Don't edit this files, because it's autogenerated.\n" +
               "# See updaters/ dir for generator. Run bin/update to update." +
               "\n\n"
    content += "module.exports =" + @stringify(sorted) + ";\n"

    if fs.existsSync(file + '.js')
      file += '.js'
      content = coffee.compile(content)
    else
      file += '.coffee'

    if fs.readFileSync(file).toString() != content
      @changed.push(name)
      fs.writeFileSync(file, content)
