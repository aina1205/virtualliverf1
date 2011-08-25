var sops_assets=new Array();
var models_assets=new Array();
var data_files_assets=new Array();
var organisms = new Array();
var assays_array = new Array();
var id_rel_array = new Array();


function postInvestigationData() {
    request = new Ajax.Request(CREATE_INVESTIGATION_LINK,
    {
        method: 'post',
        parameters: {
            id: $('study_investigation_id').value,  // empty ID will be submitted on "create" action, but it doesn't make a difference
            title: $('title').value,
            project_id: $('project_id').value
        },
        onSuccess: function(transport){
            var data = transport.responseText.evalJSON(true);
            
            if (data.status==200){                
                addNewInvestigation(data.new_investigation);
                RedBox.close();
            }
            if (data.status==406) {
                $('errorExplanation').innerHTML=data.error_messages;
                $('errorExplanation').show();
            }
            
            return (true);
        },
        onFailure: function(transport){            
            alert('Something went wrong, please try again...');
            return(false);
        }
    });

}

function addNewInvestigation(new_investigation) {
    selectObj=$('study_investigation_id');
    selectObj.options[select.options.length]=new Option(new_investigation[1],new_investigation[0],false,true);
    selectObj.disabled=false;    
}

function addSop(title,id) {
    if(checkNotInList(id,sops_assets)) {
    sops_assets.push([title,id]);
     }

}

function addSelectedSop() {
    selected_option_index=$("possible_sops").selectedIndex;
    selected_option=$("possible_sops").options[selected_option_index];
    title=selected_option.text;
    id=selected_option.value;

    if(checkNotInList(id,sops_assets)) {
        addSop(title,id);
        updateSops();
    }
    else {
    alert('The following Sop had already been added:\n\n' +
        title);
    }


}

function removeSop(index) {
    sops_assets.splice(index, 1);
    // update the page
    updateSops();
}

function updateSops() {
    sop_text='<ul class="related_asset_list">';

    sop_ids=new Array();

    for (var i=0;i<sops_assets.length;i++) {
        sop=sops_assets[i];
        title=sop[0];
        id=sop[1];
        titleText = '<span title="' + title + '">' + title.truncate(100) + '</span>';
        sop_text += '<li>' + titleText + 
          '&nbsp;&nbsp;<small style="vertical-align: middle;">' +
          '[<a href=\"\" onclick=\"javascript:removeSop('+i+'); return(false);\">remove</a>]</small></li>';
        sop_ids.push(id);
    }
    
    sop_text += '</ul>';

    // update the page
    if(sops_assets.length == 0) {
        $('sop_to_list').innerHTML = '<span class="none_text">No sops</span>';
    }
    else {
        $('sop_to_list').innerHTML = sop_text;
    }

    clearList('assay_sop_ids');

    select=$('assay_sop_ids')
    for (i=0;i<sop_ids.length;i++) {
        id=sop_ids[i];
        o=document.createElement('option');
        o.value=id;
        o.text=id;
        o.selected=true;
        try {
            select.add(o); //for older IE version
        }
        catch (ex) {
            select.add(o,null);
        }        
    }
}

//Data files
function addDataFile(title,id,relationshipType) {
     if(checkNotInList(id,data_files_assets)) {
        data_files_assets.push([title,id,relationshipType]);
     }
}

function addSelectedDataFile() {
    selected_option_index=$("possible_data_files").selectedIndex;
    selected_option=$("possible_data_files").options[selected_option_index];
    title=selected_option.text;
    id=selected_option.value;
    if ($("data_file_relationship_type")) {
        relationshipType = $("data_file_relationship_type").options[$("data_file_relationship_type").selectedIndex].text;
    }
    else
    {
        relationshipType="None"
    }

    if(checkNotInList(id,data_files_assets)) {
        addDataFile(title,id,relationshipType);
        updateDataFiles();
    }
    else {
        alert('The following Data file had already been added:\n\n' +
            title);
    }
}

function removeDataFile(index) {
    data_files_assets.splice(index, 1);
    // update the page
    updateDataFiles();
}

function updateDataFiles() {
    data_file_text='<ul class="related_asset_list">'
    
    for (var i=0;i<data_files_assets.length;i++) {        
        data_file=data_files_assets[i];
        title=data_file[0];
        id=data_file[1];
        relationshipType = data_file[2];
        relationshipText = (relationshipType == 'None') ? '' : ' <span class="assay_item_sup_info">(' + relationshipType + ')</span>';
        titleText = '<span title="' + title + '">' + title.truncate(100) + '</span>';
        data_file_text += '<li>' + titleText + relationshipText +
        '&nbsp;&nbsp;<small style="vertical-align: middle;">'
        + '[<a href="" onclick="javascript:removeDataFile('+i+'); return(false);">remove</a>]</small></li>';
    }
    
    data_file_text += '</ul>';

    // update the page
    if(data_files_assets.length == 0) {
        $('data_file_to_list').innerHTML = '<span class="none_text">No data files</span>';
    }
    else {
        $('data_file_to_list').innerHTML = data_file_text;
    }

    clearList('data_file_ids');

    select=$('data_file_ids');
    for (i=0;i<data_files_assets.length;i++) {
        id=data_files_assets[i][1];
        relationshipType=data_files_assets[i][2];
        o=document.createElement('option');
        o.value=id + "," + relationshipType;
        o.text=id;
        o.selected=true;
        try {
            select.add(o); //for older IE version
        }
        catch (ex) {
            select.add(o,null);
        }
    }
}

//Models
function addModel(title,id) {
    if(checkNotInList(id,models_assets)) {
    models_assets.push([title,id]);
    }
}

function addSelectedModel() {
    selected_option_index=$("possible_models").selectedIndex;
    selected_option=$("possible_models").options[selected_option_index];
    title=selected_option.text;
    id=selected_option.value;

    if(checkNotInList(id,models_assets)) {
        addModel(title,id);
        updateModels();
    }
    else {
        alert('The following Model had already been added:\n\n' +
            title);
    }
}

function removeModel(index) {
    models_assets.splice(index, 1);
    
    // update the page
    updateModels();
}

function updateModels() {
    model_text='<ul class="related_asset_list">';
    type="Model";
    model_ids=new Array();

    for (var i=0;i<models_assets.length;i++) {
        model=models_assets[i];
        title=model[0];
        id=model[1];
        titleText = '<span title="' + title + '">' + title.truncate(100) + '</span>';
        model_text += '<li>' + titleText
        //+ "&nbsp;&nbsp;<span style='color: #5F5F5F;'>(" + contributor + ")</span>"
        + '&nbsp;&nbsp;<small style="vertical-align: middle;">'
        + '[<a href="" onclick="javascript:removeModel('+i+'); return(false);">remove</a>]</small></li>';
        model_ids.push(id);
    }
    
    model_text += '</ul>';

    // update the page
    if(models_assets.length == 0) {
        $('model_to_list').innerHTML = '<span class="none_text">No models</span>';
    }
    else {
        $('model_to_list').innerHTML = model_text;
    }

    clearList('assay_model_ids');

    select=$('assay_model_ids');
    for (i=0;i<model_ids.length;i++) {
        id=model_ids[i];
        o=document.createElement('option');
        o.value=id;
        o.text=id;
        o.selected=true;
        try {
            select.add(o); //for older IE version
        }
        catch (ex) {
            select.add(o,null);
        }        
    }

    if (models_assets.length>=1) {
        Effect.Fade("add_model_elements");
    }
    else {
        Effect.Appear("add_model_elements");
    }
}

function check_show_add_assay() {
    i = $('possible_assays').selectedIndex;
    selected_id = $('possible_assays').options[i].value;
    if (selected_id == '0') {
        $('add_assay_link').hide();
    }
    else {
        $('add_assay_link').show();
    }
}


function addAssay(title,id,relationshipType) {
    assays_array.push([title,id,relationshipType]);
}

function addSelectedAssay() {
    selected_option_index=$("possible_assays").selectedIndex;
    selected_option=$("possible_assays").options[selected_option_index];
    title=selected_option.text;
    id=selected_option.value;
    if ($("assay_relationship_type")) {
        relationshipType = $("assay_relationship_type").options[$("assay_relationship_type").selectedIndex].text;
    }
    else
    {
        relationshipType="None"
    }

    if(checkNotInList(id,assays_array)) {
        addAssay(title,id,relationshipType);
        updateAssays();
    }
    else {
        alert('The following Data file had already been added:\n\n' +
            title);
    }
}

function updateAssays() {
    assay_text = '<ul class="related_asset_list">'
    for (var i=0;i<assays_array.length;i++) {
        assay=assays_array[i];
        title=assay[0];
        id=assay[1];
        relationshipType = assay[2];
        relationshipText = (relationshipType == 'None') ? '' : ' <span class="assay_item_sup_info">(' + relationshipType + ')</span>';
        titleText = '<span title="' + title + '">' + title.truncate(100) + '</span>';
        assay_text += '<li>' + titleText + relationshipText +
        '&nbsp;&nbsp;<small style="vertical-align: middle;">'
        + '[<a href="" onclick="javascript:removeAssay('+i+'); return(false);">remove</a>]</small></li>';
    }
    assay_text += '</ul>';

    // update the page
    if (assays_array.length == 0) {
        $('assay_to_list').innerHTML = '<span class="none_text">No assays</span>';
    }
    else {
        $('assay_to_list').innerHTML = assay_text;
    }

    clearList('assay_ids');
    select=$('assay_ids');
    for (i=0;i<assays_array.length;i++) {
        id=assays_array[i][1];
        relationshipType=assays_array[i][2];
        o=document.createElement('option');
        if (relationshipType != 'None'){
          o.value=id + "," + relationshipType
        }
        else {
            o.value=id
        }
        o.text=id;
        o.selected=true;
        try {
            select.add(o); //for older IE version
        }
        catch (ex) {
            select.add(o,null);
        }
    }
}

function removeAssay(index) {
    assays_array.splice(index, 1);
    // update the page
    updateAssays();
}

function checkOrganismNotInList(title,id,strain,culture_growth) {
        toAdd = true;

        for (var i = 0; i < organisms.length; i++){
            if (organisms[i][0] == title
                    && organisms[i][1] == id
                    && organisms[i][2] == strain
                    && organisms[i][3] == culture_growth) {

                toAdd = false;
                break;
            }
        }
        if (!toAdd) {
            alert("Organism already exists!");
        }
        return toAdd;
    }

function addOrganism(title,id,strain,culture_growth) {
    if(checkOrganismNotInList(title,id,strain,culture_growth)){
       organisms.push([title,id,strain,culture_growth]);
       updateOrganisms();
    }

}

function addSelectedOrganism() {
    selected_option_index=$("possible_organisms").selectedIndex;
    selected_option=$("possible_organisms").options[selected_option_index];
    title=selected_option.text;
    id=selected_option.value;
    strain=$('strain').value;

    selected_option_index=$('culture_growth').selectedIndex;
    selected_option=$('culture_growth').options[selected_option_index];
    if (selected_option_index==0) {
      culture_growth="";
    }else{
        culture_growth=selected_option.text;
    }

    addOrganism(title,id,strain,culture_growth);

}

function removeOrganism(index) {
    // remove according to the index
    organisms.splice(index, 1);

    // update the page
    updateOrganisms();
}

function updateOrganisms() {
    organism_text='<ul class="related_asset_list">';    

    for (var i=0;i<organisms.length;i++) {
        organism=organisms[i];
        title=organism[0];
        id=organism[1];
        strain=organism[2];
        culture_growth=organism[3];
        titleText = '<span title="' + title + '">' + title.truncate(100);
        if (strain.length>0) {
            titleText += ":"+ "<span class='assay_strain_info'> " + strain+ "</span>";
        }
        if (culture_growth.length>0 && culture_growth!='Not specified') {
            titleText += " <span class='assay_item_sup_info'>("+culture_growth+")</span>";
        }
        titleText +=  '</span>';
        organism_text += '<li>' + titleText +
          '&nbsp;&nbsp;<small style="vertical-align: middle;">' +
          '[<a href=\"\" onclick=\"javascript:removeOrganism('+i+'); return(false);\">remove</a>]</small></li>';
    }

    organism_text += '</ul>';

    // update the page
    if(organisms.length == 0) {
        $('organism_to_list').innerHTML = '<span class="none_text">No organisms</span>';
    }
    else {
        $('organism_to_list').innerHTML = organism_text;
    }

    clearList('assay_organism_ids');

    select=$('assay_organism_ids')
    for (i=0;i<organisms.length;i++) {
        organism=organisms[i];
        id=organism[1];
        strain=organism[2];
        culture_growth=organism[3];
        o=document.createElement('option');
        o.value=id;
        o.text=id;
        o.selected=true;
        o.value=id + "," + strain + "," + culture_growth;
        try {
            select.add(o); //for older IE version
        }
        catch (ex) {
            select.add(o,null);
        }
    }
}