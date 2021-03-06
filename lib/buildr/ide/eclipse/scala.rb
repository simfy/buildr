# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr
  module Eclipse
    module Scala
      include Extension

      NATURE    = 'ch.epfl.lamp.sdt.core.scalanature'
      CONTAINER = 'ch.epfl.lamp.sdt.launching.SCALA_CONTAINER'
      BUILDER   = 'ch.epfl.lamp.sdt.core.scalabuilder'

      after_define :eclipse => :eclipse_scala
      after_define :eclipse_scala do |project|
        eclipse = project.eclipse
        # smart defaults
        if eclipse.natures.empty? && (project.compile.language == :scala || project.test.compile.language == :scala)
          eclipse.natures = [NATURE, Buildr::Eclipse::Java::NATURE]
          eclipse.classpath_containers = [CONTAINER, Buildr::Eclipse::Java::CONTAINER] if eclipse.classpath_containers.empty?
          eclipse.builders = BUILDER if eclipse.builders.empty?
          eclipse.exclude_libs += Buildr::Scala::Scalac.dependencies
        end

        # :scala nature explicitly set
        if eclipse.natures.include? :scala
          unless eclipse.natures.include? NATURE
            # scala nature must be before java nature
            eclipse.natures += [Buildr::Eclipse::Java::NATURE] unless eclipse.natures.include? Buildr::Eclipse::Java::NATURE
            index = eclipse.natures.index(Buildr::Eclipse::Java::NATURE) || -1
            eclipse.natures = eclipse.natures.insert(index, NATURE)
          end
          unless eclipse.classpath_containers.include? CONTAINER
            # scala container must be before java container
            index = eclipse.classpath_containers.index(Buildr::Eclipse::Java::CONTAINER) || -1
            eclipse.classpath_containers = eclipse.classpath_containers.insert(index, CONTAINER)
          end
          unless eclipse.builders.include? BUILDER
            # scala builder overrides java builder
            eclipse.builders -= [Buildr::Eclipse::Java::BUILDER]
            eclipse.builders += [BUILDER]
          end
          eclipse.exclude_libs += Buildr::Scala::Scalac.dependencies
        end
      end

    end
  end
end

class Buildr::Project
  include Buildr::Eclipse::Scala
end
