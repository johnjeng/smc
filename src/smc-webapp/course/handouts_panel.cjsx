# SMC libraries
misc = require('smc-util/misc')
{defaults, required} = misc

# React Libraries
{React, rclass, rtypes} = require('../smc-react')
{Button, ButtonToolbar, ButtonGroup, Input, Row, Col, Panel} = require('react-bootstrap')

# SMC and course components
course_misc = require('./course_misc')
styles = require('./common_styles')
{Icon, Tip, SearchInput} = require('../r_misc')

exports.HandoutsPanel = rclass
    displayName : 'Course-editor-HandoutsPanel'

    propTypes :
        name       : rtypes.string.isRequired
        project_id : rtypes.string.isRequired
        handouts   : rtypes.object.isRequired
        students   : rtypes.object.isRequired
        user_map   : rtypes.object.isRequired
        redux      : rtypes.object.isRequired

    getInitialState : ->
        show_deleted : false
        search          : ''      # Search value for filtering handouts

    # fuck yeah immutable.js (important because compute is potentially expensive)
    shouldComponentUpdate : (nextProps, nextState) ->
        if nextProps.handouts != @props.handouts or nextProps.students != @props.students
            return true
        if nextState.search != @state.search or nextState.show_deleted != @state.show_deleted
            return true
        return false

    # also used in assignments_panel
    compute_handouts_list : ->
        console.log("compute")
        list = course_misc.immutable_to_list(@props.handouts, 'handout_id')

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

        return {handouts:list, num_omitted:num_omitted, num_deleted:num_deleted}

    render_show_deleted : (num_deleted) ->
        if @state.show_deleted
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:false)}>
                <Tip placement='left' title="Hide deleted" tip="Handouts are never really deleted.  Click this button so that deleted assignments aren't included at the bottom of the list.">
                    Hide {num_deleted} deleted assignments
                </Tip>
            </Button>
        else
            <Button style={styles.show_hide_deleted} onClick={=>@setState(show_deleted:true, search:'')}>
                <Tip placement='left' title="Show deleted" tip="Handouts are not deleted forever even after you delete them.  Click this button to show any deleted handouts at the bottom of the list of handouts.  You can then click on the handout and click undelete to bring the handout back.">
                    Show {num_deleted} deleted assignments
                </Tip>
            </Button>

    render : ->
        # Changes based on state changes so it just has to go in render
        {handouts, num_omitted, num_deleted} = @compute_handouts_list()

        header =
            <HandoutsToolBar
                search={@state.search}
                search_change={(value) => @setState(search:value)}
                num_omitted={num_omitted}
            />

        <Panel header={header}>
            Hello
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

HandoutsToolBar = rclass
    propTypes :
        search        : rtypes.string
        search_change : rtypes.func
        num_omitted   : rtypes.number

    getInitialState : ->
        add_search : rtypes.string
        add_select : rtypes.object

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
              {<h5>(Omitting {@props.num_omitted} assignments)</h5> if @props.num_omitted}
            </Col>
            <Col md=5>
            </Col>
        </Row>
