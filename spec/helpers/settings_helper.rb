def stub_settings_merge(hash)
  if defined?(::Settings)
    Settings.add_source!(hash)
    Settings.reload!
  end
end

def clear_settings
  ::Settings.keys.dup.each { |k| ::Settings.delete_field(k) } if defined?(::Settings)
end

::Config.load_and_set_settings('fake.yml')
