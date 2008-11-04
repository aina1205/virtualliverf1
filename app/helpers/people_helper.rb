module PeopleHelper
  
  def person_full_name person
    return person.profile.first_name.capitalize + " " + person.profile.last_name.capitalize
  end
  
  def person_avatar_image person
    return "avatar.png"
  end
  
  def expertises_as_comma_seperated_list expertises
    res=""
    expertises.each do |exp|
      res << exp.name
      res << ", " unless (expertises.last==exp)
    end
    return res
  end
  
  def person_list_item_extra_details? person
    !(person.projects.empty? and person.institutions.empty?)  
  end
  
end
