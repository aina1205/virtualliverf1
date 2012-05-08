require 'test_helper'

class AssayTest < ActiveSupport::TestCase
  fixtures :all


  test "shouldnt edit the assay" do
    user = users(:aaron)
    assay = assays(:modelling_assay_with_data_and_relationship)
    assert_equal false, assay.can_edit?(user)
  end

  test "sops association" do
    assay=assays(:metabolomics_assay)
    assert_equal 2,assay.sops.size
    assert assay.sops.include?(sops(:my_first_sop).versions.first)
    assert assay.sops.include?(sops(:sop_with_fully_public_policy).versions.first)
  end

  test "is_asset?" do
    assert !Assay.is_asset?
    assert !assays(:metabolomics_assay).is_asset?
  end

  test "sort by updated_at" do
    assert_equal Assay.find(:all).sort_by { |a| a.updated_at.to_i * -1 }, Assay.find(:all)
  end

  test "authorization supported?" do
    assert Assay.authorization_supported?
    assert assays(:metabolomics_assay).authorization_supported?
  end

  test "avatar_key" do
    assert_equal "assay_experimental_avatar",assays(:metabolomics_assay).avatar_key
    assert_equal "assay_modelling_avatar",assays(:modelling_assay_with_data_and_relationship).avatar_key
  end

  test "is_modelling" do
    assay=assays(:metabolomics_assay)
    User.current_user = assay.contributor.user
    assert !assay.is_modelling?
    assay.assay_class=assay_classes(:modelling_assay_class)
    assay.samples = []
    assay.save!
    assert assay.is_modelling?
  end
  
  test "title_trimmed" do
    User.with_current_user Factory(:user) do
      assay=Factory :assay,
                    :contributor => User.current_user.person,
                    :title => " test"
      assay.save!
      assert_equal "test",assay.title
    end
  end

  test "is_experimental" do
    assay=assays(:metabolomics_assay)
    User.current_user = assay.contributor.user
    assert assay.is_experimental?
    assay.assay_class=assay_classes(:modelling_assay_class)
    assay.samples = []
    assay.save!
    assert !assay.is_experimental?
  end

  test "related investigation" do
    assay=assays(:metabolomics_assay)
    assert_not_nil assay.investigation
    assert_equal investigations(:metabolomics_investigation),assay.investigation
  end

  test "related project" do
    assay=assays(:metabolomics_assay)
    assert !assay.projects.empty?
    assert assay.projects.include?(projects(:sysmo_project))
  end
  

  test "validation" do
    User.with_current_user Factory(:user) do
    assay=new_valid_assay
    
    assert assay.valid?


    assay.title=""
    assert !assay.valid?

    assay.title=nil
    assert !assay.valid?

    assay.title=assays(:metabolomics_assay).title
    assert assay.valid? #can have duplicate titles

    assay.title="test"
    assay.assay_type=nil
    assert !assay.valid?

    assay.assay_type=assay_types(:metabolomics)

    assert assay.valid?

    assay.study=nil
    assert !assay.valid?
    assay.study=studies(:metabolomics_study)

    assay.technology_type=nil
    assert !assay.valid?

    assay.technology_type=technology_types(:gas_chromatography)
    assert assay.valid?

    assay.owner=nil
    assert !assay.valid?

    assay.owner=people(:person_for_model_owner)

      #an modelling assay can be valid without a technology type, sample or organism
    assay.assay_class=assay_classes(:modelling_assay_class)
    assay.technology_type=nil
    assay.samples = []
    assert assay.valid?
    
    #an experimental assay can be invalid without a sample
    assay.assay_class=assay_classes(:experimental_assay_class)
    assay.technology_type=nil
    assay.samples = []
    assert !assay.valid?
    end
  end

  test "associated publication" do
    assert_equal 1, assays(:assay_with_a_publication).related_publications.size
  end

  test "can delete?" do
    user = User.current_user = Factory(:user)
    assert Factory(:assay, :contributor => user.person).can_delete?

    assay = Factory(:assay, :contributor => user.person)
    assay.relate Factory(:data_file, :contributor => user)
    assert !assay.can_delete?

    assay = Factory(:assay, :contributor => user.person)
    assay.relate Factory(:sop, :contributor => user)
    assert !assay.can_delete?

    assay = Factory(:assay, :contributor => user.person)
    assay.relate Factory(:model, :contributor => user)
    assert !assay.can_delete?

    pal = Factory :pal
    #create an assay with projects = to the projects for which the pal is a pal
    assay = Factory(:assay,
                    :study => Factory(:study,
                                      :investigation => Factory(:investigation,
                                                                :projects => pal.projects)))
    assert !assay.can_delete?(pal.user)
    
    assert !assays(:assay_with_a_publication).can_delete?(users(:model_owner))
  end

  test "assets" do
    assay=assays(:metabolomics_assay)
    assert_equal 3,assay.assets.size,"should be 2 sops and 1 data file"
  end

  test "sops" do
    assay=assays(:metabolomics_assay)
    assert_equal 2,assay.sops.size
    assert assay.sops.include?(sops(:my_first_sop).find_version(1))
    assert assay.sops.include?(sops(:sop_with_fully_public_policy).find_version(1))
  end

  test "data_files" do
    assay=assays(:metabolomics_assay)
    assert_equal 1,assay.data_files.size
    assert assay.data_files.include?(data_files(:picture).find_version(1))
  end
  
  test "can relate data files" do
    assay = assays(:metabolomics_assay)
    User.with_current_user assay.contributor.user do
      assert_difference("Assay.find_by_id(assay.id).data_files.count") do
        assay.relate(data_files(:viewable_data_file), relationship_types(:test_data))
      end
    end
  end
  
  test "relate new version of sop" do
    User.with_current_user Factory(:user) do
      assay=Factory :assay, :contributor => User.current_user.person
      assay.save!
      sop=sops(:sop_with_all_sysmo_users_policy)
      assert_difference("Assay.find_by_id(assay.id).sops.count", 1) do
        assert_difference("AssayAsset.count", 1) do
          assay.relate(sop)
        end
      end
      assay.reload
      assert_equal 1, assay.assay_assets.size
      assert_equal sop.version, assay.assay_assets.first.versioned_asset.version

      User.current_user = sop.contributor
      sop.save_as_new_version

      assert_no_difference("Assay.find_by_id(assay.id).sops.count") do
        assert_no_difference("AssayAsset.count") do
          assay.relate(sop)
        end
      end

      assay.reload
      assert_equal 1, assay.assay_assets.size
      assert_equal sop.version, assay.assay_assets.first.versioned_asset.version
    end
  end

  test "organisms association" do
    assay=assays(:metabolomics_assay)
    assert_equal 2,assay.assay_organisms.count
    assert_equal 2,assay.organisms.count
    assert assay.organisms.include?(organisms(:yeast))
    assert assay.organisms.include?(organisms(:Saccharomyces_cerevisiae))
  end

  test "associate organism" do
    assay=assays(:metabolomics_assay)
    User.current_user = assay.contributor
    organism=organisms(:yeast)
    #test with numeric ID
    assert_difference("AssayOrganism.count") do
      assay.associate_organism(organism.id)
    end

    #with String ID
    assert_no_difference("AssayOrganism.count") do
      assay.associate_organism(organism.id.to_s)
    end

    #with Organism object
    assert_no_difference("AssayOrganism.count") do
      assay.associate_organism(organism)
    end

    #with a culture growth
    assay.assay_organisms.clear
    assay.save!
    cg=culture_growth_types(:batch)
    assert_difference("AssayOrganism.count") do
      assay.associate_organism(organism,nil,cg)
    end
    assay.reload
    assert_equal cg,assay.assay_organisms.first.culture_growth_type

  end

  test "disassociating organisms removes AssayOrganism" do
    assay=assays(:metabolomics_assay)
    User.current_user = assay.contributor
    assert_equal 2,assay.assay_organisms.count
    assert_difference("AssayOrganism.count",-2) do
      assay.assay_organisms.clear
      assay.save!
    end
    
  end

  test "associate organism with strain" do
    assay=assays(:metabolomics_assay2)
    organism=organisms(:Streptomyces_coelicolor)
    assert_equal 0,assay.assay_organisms.count,"This test relies on this assay having no organisms"
    assert_equal 0,organism.strains.count, "This test relies on this organism having no strains"

    assert_difference("AssayOrganism.count") do
      assert_difference("Strain.count") do
        assay.associate_organism(organism,"FFFF")
      end
    end

    assert_no_difference("AssayOrganism.count") do
      assert_no_difference("Strain.count") do
        assay.associate_organism(organism,"FFFF")
      end
    end

    organism=organisms(:yeast)
    assert_difference("AssayOrganism.count") do
      assert_difference("Strain.count") do
        assay.associate_organism(organism,"FFFF")
      end
    end

  end

  test "test uuid generated" do
    a = assays(:metabolomics_assay)
    assert_nil a.attributes["uuid"]
    a.save
    assert_not_nil a.attributes["uuid"]
  end 

  test "uuid doesn't change" do
    x = assays(:metabolomics_assay)
    x.save
    uuid = x.attributes["uuid"]
    x.save
    assert_equal x.uuid, uuid
  end
  
  def new_valid_assay
    Assay.new(:title=>"test",
      :assay_type=>assay_types(:metabolomics),
      :technology_type=>technology_types(:gas_chromatography),
      :study => studies(:metabolomics_study),
      :owner => people(:person_for_model_owner),
      :assay_class => assay_classes(:experimental_assay_class),
      :samples => [Factory :sample]
    )

  end
end
