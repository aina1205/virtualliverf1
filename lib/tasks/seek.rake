require 'rubygems'
require 'rake'
require 'model_execution'

include ModelExecution

namespace :seek do
  task(:repop_cv=>:environment) do
    
    File.open('config/expertise.list').each do |item|
      unless item.blank?
        item=item.chomp
        if Person.expertise_counts.find{|tag| tag.name==item}.nil?
          tag=Tag.new(:name=>item)
          taggable=Tagging.new(:tag=>tag, :context=>"expertise",:taggable_type=>"Person")
          taggable.save!
        end
      end
    end

    File.open('config/tools.list').each do |item|
      unless item.blank?
        item=item.chomp
        if Person.tool_counts.find{|tag| tag.name==item}.nil?
          tag=Tag.new(:name=>item)
          taggable=Tagging.new(:tag=>tag, :context=>"tools",:taggable_type=>"Person")
          taggable.save!
        end
      end
    end

    File.open('config/organisms.list').each do |item|
      unless item.blank?
        item=item.chomp
        if Project.organism_counts.find{|tag| tag.name==item}.nil?
        tag=Tag.new(:name=>item)
        taggable=Tagging.new(:tag=>tag, :context=>"organisms",:taggable_type=>"Project")
        taggable.save!
        end
      end
    end

  end

  task(:jws_test=>:environment) do
    m=Model.find(1)
    puts m.title

    puts jws_execution_applet m
  end
end