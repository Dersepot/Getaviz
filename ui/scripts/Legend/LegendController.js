var legendController = (function() {
    
	var versionExplorerTreeID = "legendTree";
	var jQVersionExplorerTree = "#" + versionExplorerTreeID;
	var tree;
	var items = [];
    var controllerConfig = {
        entries: []
    };

	function initialize(setupConfig){
        application.transferConfigParams(setupConfig, controllerConfig);
    }
	
	function activate(rootDiv){
		//create zTree div-container
		var zTreeDiv = document.createElement("DIV");
		zTreeDiv.id = "zTreeDiv";

		var versionExplorerTreeUL = document.createElement("UL");
		versionExplorerTreeUL.id = versionExplorerTreeID;
		versionExplorerTreeUL.setAttribute("class", "ztree");

		zTreeDiv.appendChild(versionExplorerTreeUL);
		rootDiv.appendChild(zTreeDiv);

	    //create zTree
		prepareTreeView();
    }
	
	function reset(){
	    prepareTreeView();
	}

	function createItem(entry, parent) {
        var item = { id: entry.name, parentId: parent, name: entry.name, iconSkin: "zt", icon: entry.icon, open: true};
        items.push(item);
        if(entry.entries !== undefined) {
            var parentid = entry.name;
            entry.entries.forEach(function(entry){
                createItem(entry, parentid);
            });
        }
    }
    
    function prepareTreeView() {
        items = [];
		controllerConfig.entries.forEach(createItem);

		//zTree settings
        var settings = {
            data: {
                simpleData: {
                    enable:true,
                    idKey: "id",
                    pIdKey: "parentId",
                    rootPId: ""
                }
            },
            view:{
                showLine: false,
                showIcon: true,
                selectMulti: false,
                nameIsHTML: true,
            }
        };		
        tree = $.fn.zTree.init( $(jQVersionExplorerTree), settings, items);
    }

    return {
        initialize: initialize,
		activate: activate,
		reset: reset
    };
})();
