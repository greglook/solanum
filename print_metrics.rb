#!/usr/bin/ruby


require 'solanum'


metrics = Solanum.load_metrics("data.yml")


def print_metrics(category, ancestors=[])
    category.keys.map{|k| k.to_s }.sort.each{|k|
        path = ancestors.dup << k;
        child = category[k.intern];
        if child.is_a? Solanum::Metrics::Category
            print_metrics(child, path)
        else
            units = child.records.map{|r| r.unit }.uniq
            units.each do |unit|
                record = child.records.find{|r| r.unit == unit }
                puts "%s: %s%s" % [
                    path.join('.'),
                    record.value,
                    unit && (" " << unit.to_s) || ""
                ]
            end
        end
    }
end


print_metrics metrics.root
