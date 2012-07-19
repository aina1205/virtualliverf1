require 'test_helper'

class StrainsControllerTest < ActionController::TestCase
  fixtures :all

  include AuthenticatedTestHelper
  include RestTestCases

  def setup
    login_as :owner_of_fully_public_policy
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:strains)
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_not_nil assigns(:strain)
  end

  test "should create" do
    assert_difference("Strain.count") do
      post :create, :strain => {:title => "strain 1",
                                :organism_id => Factory(:organism).id,
                                :contributor => Factory(:user),
                                :project_ids => [Factory(:project).id]}

    end
    s = assigns(:strain)
    assert_redirected_to strain_path(s)
    assert_equal "strain 1", s.title
  end

  test "should get show" do
    get :show, :id => Factory(:strain,
                              :title => "strain 1",
                              :policy => policies(:editing_for_all_sysmo_users_policy))
    assert_response :success
    assert_not_nil assigns(:strain)
  end

  test "should get edit" do
    get :edit, :id => Factory(:strain, :policy => policies(:editing_for_all_sysmo_users_policy))
    assert_response :success
    assert_not_nil assigns(:strain)
  end

  test "should update" do
    strain = Factory(:strain, :title => "strain 1", :policy => policies(:editing_for_all_sysmo_users_policy))
    project = Factory(:project)
    assert_not_equal "test", strain.title
    assert !strain.projects.include?(project)
    put :update, :id => strain.id, :strain => {:title => "test", :project_ids => [project.id]}
    s = assigns(:strain)
    assert_redirected_to strain_path(s)
    assert_equal "test", s.title
    assert s.projects.include?(project)
  end

  test "should destroy" do
    s = Factory :strain, :contributor => User.current_user
    assert_difference("Strain.count", -1, "A strain should be deleted") do
      delete :destroy, :id => s.id
    end
  end

  test "unauthorized users cannot add new strain" do
    login_as Factory(:user, :person => Factory(:brand_new_person))
    get :new
    assert_response :redirect
  end

  test "unauthorized user cannot edit strain" do
    login_as Factory(:user, :person => Factory(:brand_new_person))
    s = Factory :strain, :policy => Factory(:private_policy)
    get :edit, :id => s.id
    assert_redirected_to strain_path(s)
    assert flash[:error]
  end
  test "unauthorized user cannot update strain" do
    login_as Factory(:user, :person => Factory(:brand_new_person))
    s = Factory :strain, :policy => Factory(:private_policy)

    put :update, :id => s.id, :strain => {:title => "test"}
    assert_redirected_to strain_path(s)
    assert flash[:error]
  end

  test "unauthorized user cannot delete strain" do
    login_as Factory(:user, :person => Factory(:brand_new_person))
    s = Factory :strain, :policy => Factory(:private_policy)
    assert_no_difference("Strain.count") do
      delete :destroy, :id => s.id
    end
    assert flash[:error]
    assert_redirected_to strains_path
  end

  test "contributor can delete strain" do
    s = Factory :strain, :contributor => User.current_user
    assert_difference("Strain.count", -1, "A strain should be deleted") do
      delete :destroy, :id => s.id
    end

    s = Factory :strain, :policy => Factory(:publicly_viewable_policy)
    assert_no_difference("Strain.count") do
      delete :destroy, :id => s.id
    end
    assert flash[:error]
    assert_redirected_to strains_path
  end

  test "should not destroy strain related to an existing specimen" do
    strain = Factory :strain
    specimen = Factory :specimen, :strain => strain
    assert !strain.specimens.empty?
    assert_no_difference("Strain.count") do
      delete :destroy, :id => strain.id
    end
    assert flash[:error]
    assert_redirected_to strains_path
  end

  test "should update genotypes and phenotypes" do
    strain = Factory(:strain)
    genotype1 = Factory(:genotype, :strain => strain)
    genotype2 = Factory(:genotype, :strain => strain)

    phenotype1 = Factory(:phenotype, :strain => strain)
    phenotype2 = Factory(:phenotype, :strain => strain)

    new_gene_title = 'new gene'
    new_modification_title = 'new modification'
    new_phenotype_description = "new phenotype"
    login_as(strain.contributor)
    #[genotype1,genotype2] =>[genotype2,new genotype]
    put :update, :id => strain.id,
        :strain => {
            :genotypes_attributes => {'0' => {:gene_attributes => {:title => genotype2.gene.title, :id => genotype2.gene.id}, :id => genotype2.id, :modification_attributes => {:title => genotype2.modification.title, :id => genotype2.modification.id}},
                                      "2" => {:gene_attributes => {:title => new_gene_title}, :modification_attributes => {:title => new_modification_title}},
                                      "1" => {:id => genotype1.id, :_destroy => 1}},
            :phenotypes_attributes => {'0' => {:description => phenotype2.description, :id => phenotype2.id}, '2343243' => {:id => phenotype1.id, :_destroy => 1}, "1" => {:description => new_phenotype_description}}
        }
    assert_redirected_to strain_path(strain)

    updated_strain = Strain.find_by_id strain.id
    new_gene = Gene.find_by_title(new_gene_title)
    new_modification = Modification.find_by_title(new_modification_title)
    new_genotype = Genotype.find(:all, :conditions => ["gene_id=? and modification_id=?", new_gene.id, new_modification.id]).first
    new_phenotype = Phenotype.find_all_by_description(new_phenotype_description).sort_by(&:created_at).last
    updated_genotypes = [genotype2, new_genotype].sort_by(&:id)
    assert_equal updated_genotypes, updated_strain.genotypes.sort_by(&:id)

    updated_phenotypes = [phenotype2, new_phenotype].sort_by(&:id)
    assert_equal updated_phenotypes, updated_strain.phenotypes.sort_by(&:id)
  end

  test "should not be able to update the policy of the strain when having no manage rights" do
    strain = Factory(:strain, :policy => Factory(:policy, :sharing_scope => Policy::ALL_SYSMO_USERS, :access_type => Policy::EDITING))
    user = Factory(:user)
    assert strain.can_edit? user
    assert !strain.can_manage?(user)

    login_as(user)
    put :update, :strain => {:id => strain.id}, :sharing => {:sharing_scope => Policy::EVERYONE, :access_type_4 => Policy::EDITING}
    assert_redirected_to strains_path

    updated_strain = Strain.find_by_id strain.id
    assert_equal Policy::ALL_SYSMO_USERS, updated_strain.policy.sharing_scope
  end

  test "should not be able to update the permissions of the strain when having no manage rights" do
    strain = Factory(:strain, :policy => Factory(:policy, :sharing_scope => Policy::ALL_SYSMO_USERS, :access_type => Policy::EDITING))
    user = Factory(:user)
    assert strain.can_edit? user
    assert !strain.can_manage?(user)

    login_as(user)
    put :update, :strain => {:id => strain.id}, :sharing => {:permissions => {:contributor_types => ActiveSupport::JSON.encode(['Person']), :values => ActiveSupport::JSON.encode({"Person" => {user.person.id => {"access_type" => Policy::MANAGING}}})}}
    assert_redirected_to strains_path

    updated_strain = Strain.find_by_id strain.id
    assert updated_strain.policy.permissions.empty?
    assert !updated_strain.can_manage?(user)
  end
end
