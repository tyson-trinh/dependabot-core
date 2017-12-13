# frozen_string_literal: true

class PythonRequirementParser
  NAME = /[a-zA-Z0-9\-_\.]+/
  EXTRA = /[a-zA-Z0-9\-_\.]+/
  COMPARISON = /===|==|>=|<=|<|>|~=|!=/
  VERSION = /[0-9]+[a-zA-Z0-9\-_\.*]*/
  REQUIREMENT = /(?<comparison>#{COMPARISON})\s*(?<version>#{VERSION})/
  HASH = /--hash=(?<algorithm>.*?):(?<hash>.*?)(?=\s|$)/
  REQUIREMENTS = /#{REQUIREMENT}(\s*,\s*#{REQUIREMENT})*/
  HASHES = /#{HASH}(\s*#{HASH})*/

  INSTALL_REQ_WITH_REQUIREMENT =
    /\s*(?<name>#{NAME})
      \s*(\[\s*(?<extras>#{EXTRA}(\s*,\s*#{EXTRA})*)\s*\])?
      \s*(?<requirements>#{REQUIREMENTS})
      \s*(?<hashes>#{HASHES})?
      \s*#*\s*(?<comment>.+)?
    /x
end
