require 'rake'
#load 'tasks/magic-localized_country_select_tasks.rake'

# = MagicLocalizedCountrySelect
#
# View helper for displaying select list with countries:
#
#     country_select(:user, :country)
#
# Works just like the default Rails' +country_select+ plugin, but stores countries as
# country *codes*, not *names*, in the database.
#
# You can easily translate country codes in your application like this:
#     <%= I18n.t @user.country, :scope => 'countries' %>
#
# Uses the Rails internationalization framework (I18n) for translating the names of countries.
#
# Use Rake task <tt>rake import:country_select LOCALE=de</tt> for importing country names
# from Unicode.org's CLDR repository (http://www.unicode.org/cldr/data/charts/summary/root.html)
#
# Code adapted from Rails' default +country_select+ plugin (previously in core)
# See http://github.com/rails/country_select/tree/master/lib/country_select.rb
#
module MagicLocalizedCountrySelect
  class MagicLocalizedCountrySelect::TranslationNotAvailable < StandardError; end
  class << self

    # Returns array with codes and localized country names (according to <tt>I18n.locale</tt>)
    # for <tt><option></tt> tags
    def localized_countries_array(options = {})
      countries = I18n.translate(:countries).clone
      alloweds = options[:alloweds]
      if alloweds.present?
        countries.slice!(*alloweds.map(&:to_sym)).inject({}) { |acum, e| acum.merge(e.first.to_s.upcase => e.last) }
        # Some alloweds might not be translated, we will display the iso code but
        # probably we should alert someone about that
        if options[:silent]
          alloweds.each { |allowed| countries[allowed.to_s] = allowed.to_s unless countries.key?(allowed) }
        else
          missing = if alloweds.length != countries.length
            alloweds - countries.keys
          else
            []
          end
          raise MagicLocalizedCountrySelect::TranslationNotAvailable.new("Missing translations: #{missing}") if missing.present?
        end
      end

      if options[:description] == :abbreviated
        countries.map { |key, value| [key.to_s] }.sort_by { |country| country.first }
      else
        countries.map { |key, value| [value, key.to_s] }.sort_by { |country| country.first }
      end
    end

    # Return array with codes and localized country names for array of country codes passed as argument
    # == Example
    #   priority_countries_array([:tw, :cn])
    #   # => [ ['Taiwan', 'tw'], ['China', 'cn'] ]
    def priority_countries_array(country_codes = [], options = {})
      if options[:description] == :abbreviated
        country_codes.map { |code| [code.to_s] }
      else
        countries = I18n.translate(:countries)
        country_codes.map { |code| [countries[code.to_s.to_sym], code.to_s] }
      end
    end
  end
end

module ActionView
  module Helpers

    module FormOptionsHelper

      # Return select and option tags for the given object and method, using +localized_country_options_for_select+
      # to generate the list of option tags. Uses <b>country code</b>, not name as option +value+.
      # Country codes listed as an array of symbols in +priority_countries+ argument will be listed first
      # TODO : Implement pseudo-named args with a hash, not the "somebody said PHP?" multiple args sillines
      def country_select(object, method, priority_countries = nil, options = {}, html_options = {})
        InstanceTag.new(object, method, self, options.delete(:object)).to_localized_country_select_tag(priority_countries, options, html_options)
      end

      # Return "named" select and option tags according to given arguments.
      # Use +selected_value+ for setting initial value
      # It behaves likes older object-binded brother +localized_country_select+ otherwise
      # TODO : Implement pseudo-named args with a hash, not the "somebody said PHP?" multiple args sillines
      def country_select_tag(name, selected_value = nil, priority_countries = nil, html_options = {})
        select_tag(name.to_sym, country_options_for_select(selected_value, priority_countries), html_options.stringify_keys)
      end

      # Returns a string of option tags for countries according to locale. Supply the country code in upper-case ('US', 'DE')
      # as +selected+ to have it marked as the selected option tag.
      # Country codes listed as an array of symbols in +priority_countries+ argument will be listed first
      def country_options_for_select(selected = nil, priority_countries = nil, options = {})
        country_options = "".html_safe
        if priority_countries.present?
          country_options += options_for_select(MagicLocalizedCountrySelect::priority_countries_array(priority_countries, options), selected)
          country_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n".html_safe
        end
        return country_options + options_for_select(MagicLocalizedCountrySelect::localized_countries_array(options), selected)
      end

    end

    class InstanceTag
      def to_localized_country_select_tag(priority_countries, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select", add_options(country_options_for_select(value, priority_countries,options), options, value), html_options)
      end
    end

    class FormBuilder
      def country_select(method, priority_countries = nil, options = {}, html_options = {})
        @template.country_select(@object_name, method, priority_countries, options.merge(:object => @object), html_options)
      end
    end

  end
end
