# This module defines stub classes for testing the instantiation methods of Ydl.
# They are not part of the application.
module LawDoc
  class Person
    attr_reader :sex, :hon, :first, :middle, :last, :name
    attr_reader :address, :phone, :fax, :email

    def initialize(sex: 'entity',
                   hon: nil,
                   first: nil,
                   last: nil,
                   middle: nil,
                   suffix: nil,
                   name: nil,
                   address: nil,
                   phone: nil,
                   fax: nil,
                   email: nil)
      @sex ||= sex.clean.downcase
      msg = "invalid sex: '#{@sex}'"
      raise ArgumentError, msg unless %w[entity male female].include?(@sex)
      @hon = hon
      @first = first
      @middle = middle
      @last = last
      @suffix = suffix
      msg = 'set name only for entities; use name components otherwise'
      raise ArgumentError, msg if name && @sex != 'entity'
      @name = name
      msg = 'address must be a LawDoc::Address'
      raise ArgumentError, msg if address && !address.is_a?(Address)
      @address = address
    end

    def self.from_hash(hsh)
      Person.new(hsh)
    end

    def to_h
      {
        sex: sex, hon: hon, first: first, last: last, middle: middle,
        name: name, address: address, phone: phone, fax: fax, email: email
      }
    end
  end

  class Address
    def initialize(
          street: nil,
          city: nil,
          state: nil,
          zip: nil,
          country: 'United States')
      case street
      when String
        @street = [street.to_s]
      when Array
        @street = street.map(&:to_s)
      end
      @city = city
      @state = state
      @zip = zip
      @country = country
    end
  end

  class Party < Person
    attr_reader :role, :lawyers

    def initialize(role: nil, lawyers: [], **other)
      if other.key?(:person)
        if other[:person].is_a?(Person)
          person_params = other[:person].to_h
          other.delete(:person)
          super(other.merge(person_params))
        elsif other[:person].is_a?(Hash)
          person_params = other[:person]
          other.delete(:person)
          super(other.merge(person_params))
        end
      else
        super(other)
      end
      @role = role
      @lawyers = lawyers
    end
  end

  class Lawyer < Person
    attr_reader :bar_numbers, :esig, :sig

    def initialize(bar_numbers: {},
                   esig: nil,
                   sig: nil,
                   **other)
      super(other)
      @bar_numbers = bar_numbers
      @esig = esig
      @sig = sig
    end
  end

  class Judge < Person
    attr_reader :title, :initials

    def initialize(initials: nil,
                   title: nil,
                   **other)
      super(other)
      @initials = initials
      @title = title
    end
  end

  class Court < Person
    def initialize(**other)
      other[:sex] = 'entity'
      super(other)
    end
  end
end
