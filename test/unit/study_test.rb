require 'test_helper'

class StudyTest < ActiveSupport::TestCase
  
  fixtures :all

  test "associations" do
    study=studies(:metabolomics_study)
    assert_equal "A Metabolomics Study",study.title

    assert_not_nil study.assays
    assert_equal 1,study.assays.size
    assert !study.investigation.projects.empty?

    assert study.assays.include?(assays(:metabolomics_assay))
    
    assert_equal projects(:sysmo_project),study.investigation.projects.first
    assert_equal projects(:sysmo_project),study.projects.first
    
    assert_equal assay_types(:metabolomics),study.assays.first.assay_type

  end

  test "sort by updated_at" do
    assert_equal Study.find(:all).sort_by { |s| s.updated_at.to_i * -1 }, Study.find(:all)
  end

  #only authorized people can delete a study, and a study must have no assays
  test "can delete" do
    project_member = Factory :person
    study = Factory :study, :contributor => Factory(:person), :investigation => Factory(:investigation, :projects => project_member.projects)
    assert !study.can_delete?(Factory(:user))
    assert !study.can_delete?(project_member.user)
    assert study.can_delete?(study.contributor.user)

    study=Factory :study, :contributor => Factory(:person), :assays => [Factory :assay]
    assert !study.can_delete?(study.contributor)
  end

  test "sops through assays" do
    study=studies(:metabolomics_study)
    assert_equal 2,study.sops.size
    assert study.sops.include?(sops(:my_first_sop).versions.first)
    assert study.sops.include?(sops(:sop_with_fully_public_policy).versions.first)
    
    #study with 2 assays that have overlapping sops. Checks that the sops aren't dupliced.
    study=studies(:study_with_overlapping_assay_sops)
    assert_equal 3,study.sops.size
    assert study.sops.include?(sops(:my_first_sop).versions.first)
    assert study.sops.include?(sops(:sop_with_fully_public_policy).versions.first)
    assert study.sops.include?(sops(:sop_for_test_with_workgroups).versions.first)
  end

  test "person responisble" do
    study=studies(:metabolomics_study)
    assert_equal people(:person_without_group),study.person_responsible
  end

  test "project from investigation" do
    study=studies(:metabolomics_study)
    assert_equal projects(:sysmo_project), study.projects.first
    assert_not_nil study.projects.first.name
  end

  test "title trimmed" do
    s=Factory(:study, :title=>" title")
    assert_equal("title",s.title)
  end
  

  test "validation" do
    s=Study.new(:title=>"title",:investigation=>investigations(:metabolomics_investigation))
    assert s.valid?

    s.title=nil
    assert !s.valid?
    s.title
    assert !s.valid?

    s=Study.new(:title=>"title",:investigation=>investigations(:metabolomics_investigation))
    s.investigation=nil
    assert !s.valid?

    #duplicate title
    s=Study.new(:title=>"A Metabolomics Study",:investigation=>investigations(:metabolomics_investigation))
    assert !s.valid?

  end

  test "study with 1 assay" do
    study=studies(:study_with_assay_with_public_private_sops_and_datafile)
    assert_equal 1,study.assays.size,"This study must have only one assay - do not modify its fixture"
  end
  
  test "test uuid generated" do
    s = studies(:metabolomics_study)
    assert_nil s.attributes["uuid"]
    s.save
    assert_not_nil s.attributes["uuid"]
  end 
  
  test "uuid doesn't change" do
    x = studies(:metabolomics_study)
    x.save
    uuid = x.attributes["uuid"]
    x.save
    assert_equal x.uuid, uuid
  end
  
end
