# SMC libraries
misc = require('smc-util/misc')
{defaults, required} = misc
{salvus_client} = require('../salvus_client')

# React Libraries
{React, rclass, rtypes} = require('../smc-react')
{Button, ButtonToolbar, ButtonGroup, Input, Row, Col, Panel, Table} = require('react-bootstrap')

# SMC and course components
course_misc = require('./course_misc')
styles = require('./common_styles')
{MultipleAddSearch} = require('./common')
{Icon, Tip, SearchInput, MarkdownInput} = require('../r_misc')

exports.HandoutsPanel = rclass
    displayName : 'Course-editor-HandoutsPanel'

    propTypes :
        name         : rtypes.string.isRequired
        project_id   : rtypes.string.isRequired
        all_handouts : rtypes.object.isRequired
        students     : rtypes.object.isRequired
        user_map     : rtypes.object.isRequired
        actions      : rtypes.object.isRequired

    getInitialState : ->
        show_deleted : false
        search          : ''      # Search value for filtering handouts

    # fuck yeah immutable.js (important because compute is potentially expensive)
    shouldComponentUpdate : (nextProps, nextState) ->
        if nextProps.all_handouts != @props.all_handouts or nextProps.students != @props.students
            return true
        if nextState.search != @state.search or nextState.show_deleted != @state.show_deleted
            return true
        return false

    # also used in assignments_panel
    compute_handouts_list : ->
        list = course_misc.immutable_to_list(@props.all_handouts, 'handout_id')

        {list, num_omitted} = course_misc.compute_match_list
            list        : list
            search_key  : 'path'
            search      : @state.search.trim()

        f = (a) -> [a.due_date ? 0, a.path?.toLowerCase()]
        compare = (a,b) => misc.cmp_array(f(a), f(b))

        {list, num_deleted} = course_misc.order_list
            list             : list
            compare_function : compare
            include_deleted  : @state.show_deleted

        return {shown_handouts:list, num_omitted:num_omitted, num_deleted:num_deleted}

    render_show_deleted : (num_deleted) ->
        if @state.show_deleted
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:false)}>
                <Tip placement='left' title="Hide deleted" tip="Handouts are never really deleted.  Click this button so that deleted assignments aren't included at the bottom of the list.">
                    Hide {num_deleted} deleted handouts
                </Tip>
            </Button>
        else
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:true, search:'')}>
                <Tip placement='left' title="Show deleted" tip="Handouts are not deleted forever even after you delete them.  Click this button to show any deleted handouts at the bottom of the list of handouts.  You can then click on the handout and click undelete to bring the handout back.">
                    Show {num_deleted} deleted handouts
                </Tip>
            </Button>

    render : ->
        # Changes based on state changes so it just has to go in render
        {shown_handouts, num_omitted, num_deleted} = @compute_handouts_list()
        header =
            <HandoutsToolBar
                search        = {@state.search}
                search_change = {(value) => @setState(search:value)}
                num_omitted   = {num_omitted}
                project_id    = {@props.project_id}
                handouts      = {@props.all_handouts}
                add_handouts  = {(paths)=>paths.map(@props.actions.add_assignment)}
            />

        <Panel header={header}>
            {for handout, i in shown_handouts
                <Handout background={if i%2==0 then "#eee"}  key={handout.assignment_id}
                        handout={@props.all_handouts.get(handout.assignment_id)} project_id={@props.project_id}
                        students={@props.students} user_map={@props.user_map} actions={@props.actions}
                />}
            {@render_show_deleted(num_deleted) if num_deleted > 0}
        </Panel>

exports.HandoutsPanel.Header = rclass
    propTypes :
        n : rtypes.number

    render: ->
        <Tip delayShow=1300
             title="Handouts"
             tip="This tab lists all of the handouts associated with your course.">
            <span>
                <Icon name="files-o"/> Handouts {if @props.n? then " (#{@props.n})" else ""}
            </span>
        </Tip>

# State here is messy AF
HandoutsToolBar = rclass
    propTypes :
        search        : rtypes.string
        search_change : rtypes.func
        num_omitted   : rtypes.number
        project_id    : rtypes.string
        all_handouts  : rtypes.object
        add_handouts  : rtypes.func      # should expect an array of paths

    getInitialState : ->
        add_is_searching : false

    # Should the client call really be here?
    do_add_search : (search) ->
        if @state.add_is_searching
            return
        @setState(add_is_searching:true)
        salvus_client.find_directories
            project_id : @props.project_id
            query      : "*#{search.trim()}*"
            cb         : (err, resp) =>
                if err
                    @setState(add_is_searching:false, err:err, add_select:undefined)
                else
                    @setState(add_is_searching:false, add_search_results:@filter_results(resp.directories, search, @props.all_handouts))

    # TODO: see if this is common to assignments and students
    filter_results : (directories, search, all_handouts) ->
        if directories.length > 0
            # Omit any -collect directory (unless explicitly searched for).
            # Omit any currently assigned directory, or any subdirectory of any
            # assigned directory.
            omit_prefix = []
            all_handouts.map (val, key) =>
                path = val.get('path')
                if path  # path might not be set in case something went wrong (this has been hit in production)
                    omit_prefix.push(path)
            omit = (path) =>
                if path.indexOf('-collect') != -1 and search.indexOf('collect') == -1
                    # omit assignment collection folders unless explicitly searched (could cause confusion...)
                    return true
                for p in omit_prefix
                    if path == p
                        return true
                    if path.slice(0, p.length+1) == p+'/'
                        return true
                return false
            directories = (path for path in directories when not omit(path))
            directories.sort()
        return directories

    render : ->
        <Row>
            <Col md=3>
                <SearchInput
                    placeholder   = 'Search Bar'
                    default_value = {@props.search}
                    on_change     = {@props.search_change}
                />
            </Col>
            <Col md=4>
              {<h5>(Omitting {@props.num_omitted} handouts)</h5> if @props.num_omitted}
            </Col>
            <Col md=5>
                <MultipleAddSearch
                    add_selected   = {@props.add_handouts}
                    do_search      = {@do_add_search}
                    is_searching   = {@state.add_is_searching}
                    item_name      = {"handout"}
                    err            = {undefined}
                    search_results = {@state.add_search_results}
                 />
            </Col>
        </Row>

Handout = rclass
    propTypes :
        handout             : rtypes.object
        background          : rtypes.string

    getInitialState : ->
        more : false
        confirm_delete : false

    render_more_header : ->
        <div>
            <Button>Edit handout</Button>
        </div>

    render_handout_notes : ->
        <Row key='note' style={styles.note}>
            <Col xs=2>
                <Tip title="Notes about this handout" tip="Record notes about this handout here. These notes are only visible to you, not to your students.  Put any instructions to students about assignments in a file in the directory that contains the assignment.">
                    Private Handout Notes<br /><span style={color:"#666"}></span>
                </Tip>
            </Col>
            <Col xs=10>
                <MarkdownInput
                    rows          = 6
                    placeholder   = 'Private notes about this assignment (not visible to students)'
                    default_value = {@props.handout.get('note')}
                    on_save       = {(value)=>@props.actions.set_assignment_note(@props.assignment, value)}
                />
            </Col>
        </Row>

    render_more : ->
        <Row key='more'>
            <Col sm=12>
                <Panel header={@render_more_header()}>
                    <StudentListForHandout handout={@props.handout} students={@props.students}
                        user_map={@props.user_map} />

                    {@render_handout_notes()}
                </Panel>
            </Col>
        </Row>

    render : ->
        <Row style={if @state.more then styles.selected_entry else styles.entry}>
            <Col xs=12>
                <Row key='summary' style={backgroundColor:@props.background}>
                    <Col md=6>
                        <h5>
                            <a href='' onClick={(e)=>e.preventDefault();@setState(more:not @state.more)}>
                                <Icon style={marginRight:'10px'}
                                      name={if @state.more then 'caret-down' else 'caret-right'} />
                                <span>
                                    {misc.trunc_middle(@props.handout.get('path'), 80)}
                                    {<b> (deleted)</b> if @props.handout.get('deleted')}
                                </span>
                            </a>
                        </h5>
                    </Col>
                    <Col md=3>
                        Distributed / Not Distributed
                    </Col>
                    <Col md=3>
                        <Tip placement='left' title="Distribute" tip="Copy this folder to all your students projects.">
                            <Button>Distribute</Button>/<Button>Re-distribute</Button>
                        </Tip>
                    </Col>
                </Row>
                {@render_more() if @state.more}
            </Col>
        </Row>

StudentListForHandout = rclass
    propTypes :
        user_map : rtypes.object
        students : rtypes.object
        handouts : rtypes.object

    render_students : ->
        v = course_misc.immutable_to_list(@props.students, 'student_id')
        # fill in names, for use in sorting and searching (TODO: caching)
        v = (x for x in v when not x.deleted)
        for x in v
            user = @props.user_map.get(x.account_id)
            if user?
                x.first_name = user.get('first_name')
                x.last_name  = user.get('last_name')
                x.name = x.first_name + ' ' + x.last_name
                x.sort = (x.last_name + ' ' + x.first_name).toLowerCase()
            else if x.email_address?
                x.name = x.sort = x.email_address.toLowerCase()

        v.sort (a,b) ->
            return misc.cmp(a.sort, b.sort)

        for x in v
            @render_student_info(x.student_id, x)

    render_student_info : (id, student) ->
        <tr key={id}>
            <td>{student.first_name + ' ' + student.last_name}</td>
            <td>{id}</td>
            <td>{"Delete?"}</td>
            <td>Table cell</td>
        </tr>

    render : ->
        <Table responsive>
            <thead>
                <tr>
                    <th>Student</th>
                    <th>Distribute to Student</th>
                    <th>Delete Student Copy</th>
                    <th>Push new version</th>
                </tr>
            </thead>
            <tbody>
                {@render_students()}
            </tbody>
        </Table>
